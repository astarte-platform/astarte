#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.AppEngine.API.Groups.Queries do
  alias Astarte.AppEngine.API.Groups.GroupedDevice, as: GroupedDevice
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Devices.Device, as: DataAccessDevice
  alias Astarte.AppEngine.API.Realm, as: DataAccessRealm
  alias Astarte.Core.CQLUtils
  alias Astarte.AppEngine.API.Config
  alias Astarte.Core.Device
  alias Astarte.Core.Realm
  alias Astarte.AppEngine.API.Repo

  require Logger
  import Ecto.Query

  def list_devices(realm_name, group_name, opts \\ []) do
    keyspace = DataAccessRealm.keyspace_name(realm_name)

    if(opts[:details],
      do: list_devices_with_details(keyspace, group_name, opts),
      else: list_grouped_devices(keyspace, group_name, opts)
    )
  end

  defp list_devices_with_details(keyspace, group_name, opts) do
    limit = opts[:limit]
    query = list_devices_with_details_query(keyspace, group_name, opts) |> limit(^limit)

    case Repo.all(query) do
      [] -> {:error, :group_not_found}
      devices -> {:ok, build_device_list(keyspace, devices, opts)}
    end
  end

  defp list_grouped_devices(keyspace, group_name, opts) do
    query = list_grouped_devices_query(keyspace, group_name, opts)

    case Repo.all(query) do
      [] -> {:error, :group_not_found}
      devices -> {:ok, build_device_list(keyspace, devices, opts)}
    end
  end

  def add_device(realm_name, group_name, device_changeset) do
    Xandra.Cluster.run(:xandra, fn conn ->
      with {:ok, %{device_id: device_id}} <-
             Ecto.Changeset.apply_action(device_changeset, :insert),
           {:group_exists?, true} <-
             {:group_exists?, group_exists?(conn, realm_name, group_name)},
           :ok <- check_valid_device_for_group(conn, realm_name, group_name, device_id),
           :ok <- add_to_group(conn, realm_name, group_name, [device_id]) do
        :ok
      else
        {:group_exists?, false} ->
          {:error, :group_not_found}

        {:error, :device_not_found} ->
          error_changeset =
            device_changeset
            |> Ecto.Changeset.add_error(:device_id, "does not exist")

          {:error, error_changeset}

        {:error, %Ecto.Changeset{} = error_changeset} ->
          {:error, error_changeset}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  def remove_device(realm_name, group_name, device_id) do
    Xandra.Cluster.run(:xandra, fn conn ->
      with {:group_exists?, true} <-
             {:group_exists?, group_exists?(conn, realm_name, group_name)},
           :ok <- remove_from_group(conn, realm_name, group_name, device_id) do
        :ok
      else
        {:group_exists?, false} ->
          {:error, :group_not_found}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  def check_device_in_group(realm_name, group_name, device_id) do
    Xandra.Cluster.run(:xandra, fn conn ->
      do_check_device_in_group(conn, realm_name, group_name, device_id)
    end)
  end

  defp list_devices_with_details_query(keyspace, group_name, opts) do
    previous_token = opts[:from_token]
    limit = opts[:limit]

    from_previous_token =
      if previous_token,
        do: dynamic([d], fragment("TOKEN(?)", d.device_id) > ^previous_token),
        else: true

    # TODO: this needs to be done with ALLOW FILTERING, so it's not particularly efficient
    from d in DataAccessDevice,
      prefix: ^keyspace,
      hints: ["ALLOW FILTERING"],
      select: %{
        token: fragment("TOKEN(?)", d.device_id),
        device_id: d.device_id,
        aliases: d.aliases,
        introspection: d.introspection,
        inhibit_credentials_request: d.inhibit_credentials_request,
        introspection_minor: d.introspection_minor,
        connected: d.connected,
        last_connection: d.last_connection,
        last_disconnection: d.last_disconnection,
        first_registration: d.first_registration,
        first_credentials_request: d.first_credentials_request,
        last_credentials_request_ip: d.last_credentials_request_ip,
        last_seen_ip: d.last_seen_ip,
        total_received_msgs: d.total_received_msgs,
        total_received_bytes: d.total_received_bytes,
        groups: d.groups,
        exchanged_msgs_by_interface: d.exchanged_msgs_by_interface,
        exchanged_bytes_by_interface: d.exchanged_bytes_by_interface,
        old_introspection: d.old_introspection,
        attributes: d.attributes
      },
      where: ^from_previous_token,
      where: fragment("? CONTAINS KEY ?", d.groups, ^group_name),
      limit: ^limit
  end

  defp list_grouped_devices_query(keyspace, group_name, opts) do
    previous_token = opts[:from_token]
    limit = opts[:limit]

    from_previous_token =
      if previous_token,
        do: dynamic([d], d.insertion_uuid > ^previous_token),
        else: true

    from GroupedDevice,
      prefix: ^keyspace,
      select: [:insertion_uuid, :device_id],
      where: [group_name: ^group_name],
      where: ^from_previous_token,
      limit: ^limit
  end

  defp build_device_list(realm_name, result, opts) do
    {row_to_device_fun, row_to_token_fun} =
      if opts[:details] do
        {&compute_device_status(realm_name, &1), &Map.get(&1, :token)}
      else
        {fn %{:device_id => device_id} -> Device.encode_device_id(device_id) end,
         &(Map.get(&1, :insertion_uuid) |> Ecto.UUID.load())}
      end

    {device_list, last_token, count} =
      Enum.reduce(result, {[], nil, 0}, fn row, {device_list, _token, count} ->
        latest_token =
          case row_to_token_fun.(row) do
            {:ok, value} -> value
            val -> val
          end

        device = row_to_device_fun.(row)

        {[device | device_list], latest_token, count + 1}
      end)

    if count < opts[:limit] do
      %DevicesList{devices: Enum.reverse(device_list)}
    else
      %DevicesList{devices: Enum.reverse(device_list), last_token: last_token}
    end
  end

  defp compute_device_status(realm_name, device_row) do
    %{
      device_id: device_id
    } = device_row

    device_status = DeviceStatus.from_db_row(device_row)
    # TODO: rebase on newer devicestatus
    deletion_in_progress? = deletion_in_progress?(realm_name, device_id)
    %{device_status | deletion_in_progress: deletion_in_progress?}
  end

  defp deletion_in_progress?(realm_name, device_id) do
    Xandra.Cluster.run(:xandra, fn conn ->
      # TODO change this once NoaccOS' PR is in
      deletion_in_progress_stmt = """
      SELECT *
      FROM :keyspace.deletion_in_progress
      WHERE device_id=:device_id
      """

      with {:ok, prepared} <- prepare_with_realm(conn, realm_name, deletion_in_progress_stmt),
           {:ok, %Xandra.Page{} = page} <-
             Xandra.execute(conn, prepared, %{"device_id" => device_id}) do
        if Enum.empty?(page), do: false, else: true
      else
        # Default to false, as done for the connected field (see device/queries.ex, line 690)

        {:error, %Xandra.ConnectionError{} = err} ->
          _ =
            Logger.warning("Database conection error: #{Exception.message(err)}",
              tag: "db_connection_error"
            )

          false

        {:error, %Xandra.Error{} = err} ->
          _ = Logger.warning("Database error: #{Exception.message(err)}", tag: "db_error")
          false
      end
    end)
  end

  defp check_valid_device_for_group(conn, realm_name, group_name, device_id) do
    with {:exists?, true} <- {:exists?, device_exists?(conn, realm_name, device_id)},
         {:in_group?, {:ok, false}} <-
           {:in_group?, do_check_device_in_group(conn, realm_name, group_name, device_id)} do
      :ok
    else
      {:exists?, false} ->
        {:error, :device_not_found}

      {:in_group?, {:ok, true}} ->
        {:error, :device_already_in_group}

      {:in_group?, {:error, reason}} ->
        {:error, reason}
    end
  end

  defp device_exists?(conn, realm_name, encoded_device_id) do
    query = "SELECT device_id FROM :keyspace.devices WHERE device_id = :device_id"

    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"device_id" => device_id}),
         [_device_id] <- Enum.to_list(page) do
      true
    else
      {:error, reason} ->
        _ = Logger.error("Database error: #{inspect(reason)}.", tag: "db_error")
        false

      [] ->
        false
    end
  end

  defp group_exists?(conn, realm_name, group_name) do
    query = "SELECT group_name FROM :keyspace.grouped_devices WHERE group_name = :group_name"

    with {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"group_name" => group_name}),
         [%{"group_name" => ^group_name} | _] <- Enum.to_list(page) do
      true
    else
      {:error, reason} ->
        _ = Logger.error("Database error: #{inspect(reason)}.", tag: "db_error")
        false

      [] ->
        false
    end
  end

  defp do_check_device_in_group(conn, realm_name, group_name, encoded_device_id) do
    query = """
      SELECT groups
      FROM :keyspace.devices
      WHERE device_id = :device_id
    """

    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"device_id" => device_id}),
         [%{"groups" => groups}] <- Enum.to_list(page) do
      # groups could be nil if it was never set, use a default empty map
      in_group? =
        (groups || %{})
        |> Map.has_key?(group_name)

      {:ok, in_group?}
    else
      {:error, :invalid_device_id} ->
        {:error, :device_not_found}

      {:error, reason} ->
        _ = Logger.error("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}

      [] ->
        {:error, :device_not_found}
    end
  end

  defp remove_from_group(conn, realm_name, group_name, encoded_device_id) do
    device_query = """
      UPDATE :keyspace.devices
      SET groups = groups - :group_name_set
      WHERE device_id = :device_id
    """

    grouped_devices_query = """
      DELETE FROM :keyspace.grouped_devices
      WHERE group_name = :group_name
      AND insertion_uuid = :insertion_uuid
      AND device_id = :device_id
    """

    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, insertion_uuid} <-
           retrieve_group_insertion_uuid(conn, realm_name, group_name, device_id),
         {:ok, device_prepared} <- prepare_with_realm(conn, realm_name, device_query),
         {:ok, grouped_devices_prepared} <-
           prepare_with_realm(conn, realm_name, grouped_devices_query),
         batch =
           Xandra.Batch.new()
           |> Xandra.Batch.add(device_prepared, %{
             "group_name_set" => MapSet.new([group_name]),
             "device_id" => device_id
           })
           |> Xandra.Batch.add(grouped_devices_prepared, %{
             "group_name" => group_name,
             "insertion_uuid" => insertion_uuid,
             "device_id" => device_id
           }),
         {:ok, %Xandra.Void{}} <- Xandra.execute(conn, batch) do
      :ok
    else
      {:error, :invalid_device_id} ->
        {:error, :device_not_found}

      {:error, :device_not_found} ->
        {:error, :device_not_found}

      {:error, reason} ->
        _ = Logger.error("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  defp retrieve_group_insertion_uuid(conn, realm_name, group_name, device_id) do
    query = """
      SELECT groups
      FROM :keyspace.devices
      WHERE device_id = :device_id
    """

    with {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"device_id" => device_id}),
         [%{"groups" => groups}] <- Enum.to_list(page),
         {:ok, insertion_uuid} <- Map.fetch(groups || %{}, group_name) do
      {:ok, insertion_uuid}
    else
      [] ->
        # Device is not present in realm
        {:error, :device_not_found}

      :error ->
        # Device was not in group
        {:error, :device_not_found}

      {:error, reason} ->
        _ = Logger.error("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  defp add_to_group(conn, realm_name, group_name, devices) do
    device_query = """
      UPDATE :keyspace.devices
      SET groups = groups + :group_map
      WHERE device_id = :device_id
    """

    grouped_devices_query = """
      INSERT INTO :keyspace.grouped_devices
      (group_name, insertion_uuid, device_id)
      VALUES
      (:group_name, :insertion_uuid, :device_id)
    """

    with {:ok, device_prepared} <- prepare_with_realm(conn, realm_name, device_query),
         {:ok, grouped_devices_prepared} <-
           prepare_with_realm(conn, realm_name, grouped_devices_query) do
      {batch, _uuid_state} =
        Enum.reduce(devices, {Xandra.Batch.new(), :uuid.new(self())}, fn encoded_device_id,
                                                                         {batch, uuid_state} ->
          # We can be sure that this succeeds since it was validated in `check_all_devices_exist`
          {:ok, device_id} = Device.decode_device_id(encoded_device_id)

          # TODO: in the future we probably want to check that this generated insertion_uuid
          # is greater than the last insertion_uuid in the grouped_devices column
          {insertion_uuid, new_uuid_state} = :uuid.get_v1(uuid_state)

          group_map = %{group_name => insertion_uuid}

          new_batch =
            batch
            |> Xandra.Batch.add(device_prepared, %{
              "group_map" => group_map,
              "device_id" => device_id
            })
            |> Xandra.Batch.add(grouped_devices_prepared, %{
              "group_name" => group_name,
              "insertion_uuid" => insertion_uuid,
              "device_id" => device_id
            })

          {new_batch, new_uuid_state}
        end)

      case Xandra.execute(conn, batch) do
        {:ok, %Xandra.Void{}} ->
          :ok

        {:error, reason} ->
          _ = Logger.error("Database error: #{inspect(reason)}.", tag: "db_error")
          {:error, :database_error}
      end
    end
  end

  defp prepare_with_realm(conn, realm_name, query) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    with {:valid, true} <- {:valid, Realm.valid_name?(realm_name)},
         query_with_keyspace = String.replace(query, ":keyspace", keyspace_name),
         {:ok, prepared} <- Xandra.prepare(conn, query_with_keyspace) do
      {:ok, prepared}
    else
      {:valid, false} ->
        {:error, :not_found}

      {:error, reason} ->
        _ = Logger.error("Database error: #{inspect(reason)}.")
        {:error, :database_error}
    end
  end
end
