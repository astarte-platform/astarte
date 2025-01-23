# Copyright 2019-2024 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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
  alias Astarte.AppEngine.API.Groups.Group
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.Core.CQLUtils
  alias Astarte.AppEngine.API.Config
  alias Astarte.Core.Device
  alias Astarte.Core.Realm

  require Logger

  def create_group(realm_name, group_changeset) do
    Xandra.Cluster.run(:xandra, fn conn ->
      with {:ok, %Group{devices: devices, group_name: group_name} = group} <-
             Ecto.Changeset.apply_action(group_changeset, :insert),
           :ok <- check_all_devices_exist(conn, realm_name, devices),
           {:group_exists?, false} <-
             {:group_exists?, group_exists?(conn, realm_name, group_name)},
           :ok <- add_to_group(conn, realm_name, group_name, devices) do
        {:ok, group}
      else
        {:group_exists?, true} ->
          {:error, :group_already_exists}

        {:error, {:device_not_found, device_id}} ->
          error_changeset =
            group_changeset
            |> Ecto.Changeset.add_error(:devices, "must exist (#{device_id} not found)")

          {:error, error_changeset}

        {:error, %Ecto.Changeset{} = error_changeset} ->
          {:error, error_changeset}
      end
    end)
  end

  def list_groups(realm_name) do
    Xandra.Cluster.run(:xandra, fn conn ->
      query = "SELECT DISTINCT group_name FROM :keyspace.grouped_devices"

      with {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
           {:ok, %Xandra.Page{} = page} <- Xandra.execute(conn, prepared) do
        {:ok, Enum.map(page, fn %{"group_name" => group_name} -> group_name end)}
      else
        {:error, reason} ->
          _ = Logger.error("Database error: #{inspect(reason)}.", tag: "db_error")
          {:error, :database_error}
      end
    end)
  end

  def get_group(realm_name, group_name) do
    Xandra.Cluster.run(:xandra, fn conn ->
      query = """
        SELECT DISTINCT group_name
        FROM :keyspace.grouped_devices
        WHERE group_name = :group_name
      """

      with {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
           {:ok, %Xandra.Page{} = page} <-
             Xandra.execute(conn, prepared, %{"group_name" => group_name}),
           [%{"group_name" => ^group_name}] <- Enum.to_list(page) do
        {:ok, %Group{group_name: group_name}}
      else
        [] ->
          {:error, :group_not_found}

        {:error, reason} ->
          _ = Logger.error("Database error: #{inspect(reason)}.", tag: "db_error")
          {:error, :database_error}
      end
    end)
  end

  def list_devices(realm_name, group_name, opts \\ []) do
    Xandra.Cluster.run(:xandra, fn conn ->
      query = build_list_devices_statement(opts)

      # We put them all, even if some of them could be ignored depending on the query
      parameters = %{
        "group_name" => group_name,
        "previous_token" => opts[:from_token],
        "page_size" => opts[:limit]
      }

      with {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
           {:ok, %Xandra.Page{} = page} <-
             Xandra.execute(conn, prepared, parameters, uuid_format: :binary),
           result when result != [] <- Enum.to_list(page) do
        {:ok, build_device_list(realm_name, result, opts)}
      else
        [] ->
          {:error, :group_not_found}

        {:error, reason} ->
          _ = Logger.error("Database error: #{inspect(reason)}.", tag: "db_error")
          {:error, :database_error}
      end
    end)
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

  defp build_list_devices_statement(opts) do
    {select, from, where, suffix} =
      if opts[:details] do
        select = """
        SELECT TOKEN(device_id), device_id, aliases, introspection, inhibit_credentials_request,
        introspection_minor, connected, last_connection, last_disconnection,
        first_registration, first_credentials_request, last_credentials_request_ip,
        last_seen_ip, total_received_msgs, total_received_bytes, groups,
        exchanged_msgs_by_interface, exchanged_bytes_by_interface, old_introspection,
        attributes
        """

        from = """
        FROM :keyspace.devices
        """

        where =
          if opts[:from_token] do
            """
            WHERE TOKEN(device_id) > :previous_token
            AND groups CONTAINS KEY :group_name
            """
          else
            """
            WHERE groups CONTAINS KEY :group_name
            """
          end

        # TODO: this needs to be done with ALLOW FILTERING, so it's not particularly efficient
        suffix = """
        LIMIT :page_size
        ALLOW FILTERING
        """

        {select, from, where, suffix}
      else
        select = """
        SELECT insertion_uuid, device_id
        """

        from = """
        FROM :keyspace.grouped_devices
        """

        where =
          if opts[:from_token] do
            """
            WHERE group_name = :group_name
            AND insertion_uuid > :previous_token
            """
          else
            """
            WHERE group_name = :group_name
            """
          end

        suffix = """
        LIMIT :page_size
        """

        {select, from, where, suffix}
      end

    select <> from <> where <> suffix
  end

  defp build_device_list(realm_name, result, opts) do
    {row_to_device_fun, row_to_token_fun} =
      if opts[:details] do
        {&compute_device_status(realm_name, &1), &Map.get(&1, "system.token(device_id)")}
      else
        {fn %{"device_id" => device_id} -> Device.encode_device_id(device_id) end,
         &Map.get(&1, "insertion_uuid")}
      end

    {device_list, last_token, count} =
      Enum.reduce(result, {[], nil, 0}, fn row, {device_list, _token, count} ->
        latest_token = row_to_token_fun.(row)
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
    %{"device_id" => device_id} = device_row
    device_status = DeviceStatus.from_db_row(device_row)
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

  defp check_all_devices_exist(_conn, _realm_name, []) do
    :ok
  end

  defp check_all_devices_exist(conn, realm_name, [device_id | tail]) do
    if device_exists?(conn, realm_name, device_id) do
      check_all_devices_exist(conn, realm_name, tail)
    else
      {:error, {:device_not_found, device_id}}
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
