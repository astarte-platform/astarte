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
  alias Astarte.AppEngine.API.Groups.Group
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.DeletionInProgress
  alias Astarte.AppEngine.API.Devices.Device, as: DataBaseDevice
  alias Astarte.AppEngine.API.Realm, as: DataAccessRealm
  alias Astarte.Core.CQLUtils
  alias Astarte.AppEngine.API.Config
  alias Astarte.Core.Device
  alias Astarte.Core.Realm
  alias Astarte.AppEngine.API.Repo
  alias Ecto.Changeset

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
    query = list_devices_with_details_query(keyspace, group_name, opts)

    query =
      case Keyword.fetch(opts, :limit) do
        {:ok, limit} -> query |> limit(^limit)
        :error -> query
      end

    case Repo.all(query) do
      [] -> {:error, :group_not_found}
      devices -> {:ok, build_device_list_with_details(keyspace, devices, opts)}
    end
  end

  defp list_grouped_devices(keyspace, group_name, opts) do
    query = list_grouped_devices_query(keyspace, group_name, opts)

    case Repo.all(query) do
      [] -> {:error, :group_not_found}
      devices -> {:ok, build_device_list(devices, opts)}
    end
  end

  def add_device(realm_name, group_name, device_changeset) do
    Xandra.Cluster.run(:xandra, fn conn ->
      with {:ok, %{device_id: device_id}} <-
             Ecto.Changeset.apply_action(device_changeset, :insert),
           {:group_exists?, true} <-
             {:group_exists?, group_exists?(realm_name, group_name)},
           :ok <- check_valid_device_for_group(realm_name, group_name, device_id),
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
    with {:group_exists?, true} <-
           {:group_exists?, group_exists?(realm_name, group_name)},
         keyspace = DataAccessRealm.keyspace_name(realm_name),
         :ok <- remove_from_group(keyspace, group_name, device_id) do
      :ok
    else
      {:group_exists?, false} ->
        {:error, :group_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retrieve_group_insertion_uuid(keyspace, group_name, device_id) do
    with {:ok, groups} <- fetch_device_groups(keyspace, device_id) do
      groups = groups || %{}

      case Map.fetch(groups, group_name) do
        {:ok, insertion_uuid} ->
          {:ok, insertion_uuid}

        :error ->
          # Device was not in group
          {:error, :device_not_found}
      end
    end
  end

  defp fetch_device_groups(keyspace, encoded_device_id) do
    query = from d in DataBaseDevice, prefix: ^keyspace, select: d.groups

    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id) do
      Repo.fetch(query, device_id, error: :device_not_found)
    end
  end

  def check_device_in_group(realm_name, group_name, device_id) do
    keyspace = DataAccessRealm.keyspace_name(realm_name)

    case fetch_device_groups(keyspace, device_id) do
      {:ok, groups} -> {:ok, Map.has_key?(groups, group_name)}
      {:error, _reason} -> {:error, :device_not_found}
    end
  end

  defp list_devices_with_details_query(keyspace, group_name, opts) do
    previous_token = opts[:from_token]

    from_previous_token =
      if previous_token,
        do: dynamic([d], fragment("TOKEN(?)", d.device_id) > ^previous_token),
        else: true

    # TODO: this needs to be done with ALLOW FILTERING, so it's not particularly efficient
    query =
      from d in DataBaseDevice,
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
        where: fragment("? CONTAINS KEY ?", d.groups, ^group_name)

    case Keyword.fetch(opts, :limit) do
      {:ok, limit} -> query |> limit(^limit)
      :error -> query
    end
  end

  defp list_grouped_devices_query(keyspace, group_name, opts) do
    previous_token = opts[:from_token]

    from_previous_token =
      if previous_token,
        do: dynamic([d], d.insertion_uuid > ^previous_token),
        else: true

    query =
      from GroupedDevice,
        prefix: ^keyspace,
        select: [:insertion_uuid, :device_id],
        where: [group_name: ^group_name],
        where: ^from_previous_token

    case Keyword.fetch(opts, :limit) do
      {:ok, limit} -> query |> limit(^limit)
      :error -> query
    end
  end

  defp build_device_list(result, opts) do
    {row_to_device_fun, row_to_token_fun} =
      {fn %{:device_id => device_id} -> Device.encode_device_id(device_id) end,
       &(Map.get(&1, :insertion_uuid) |> Ecto.UUID.load!())}

    do_build_device_list(result, opts, row_to_device_fun, row_to_token_fun)
  end

  defp build_device_list_with_details(keyspace, result, opts) do
    {row_to_device_fun, row_to_token_fun} =
      {&compute_device_status(keyspace, &1), &Map.get(&1, :token)}

    do_build_device_list(result, opts, row_to_device_fun, row_to_token_fun)
  end

  defp do_build_device_list(
         result,
         opts,
         row_to_device_fun,
         row_to_token_fun
       ) do
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
    %{
      device_id: device_id
    } = device_row

    device_status = DeviceStatus.from_db_row(device_row)
    deletion_in_progress? = deletion_in_progress?(realm_name, device_id)
    %{device_status | deletion_in_progress: deletion_in_progress?}
  end

  defp deletion_in_progress?(realm_name, device_id) do
    keyspace = DataAccessRealm.keyspace_name(realm_name)

    case Repo.fetch(DeletionInProgress, device_id, prefix: keyspace) do
      {:ok, _} ->
        true

      _error ->
        _ = Logger.warning("Database error", tag: "db_error")
        false
    end
  end

  defp check_valid_device_for_group(keyspace, group_name, device_id) do
    with {:ok, groups} <- fetch_device_groups(keyspace, device_id),
         :ok <- check_device_not_in_group(groups, group_name) do
      :ok
    end
  end

  defp check_device_not_in_group(groups, group_name) do
    case Map.has_key?(groups, group_name) do
      false -> :ok
      true -> {:error, :device_already_in_group}
    end
  end

  defp group_exists?(realm_name, group_name) do
    keyspace = DataAccessRealm.keyspace_name(realm_name)

    query =
      from d in GroupedDevice,
        prefix: ^keyspace,
        where: d.group_name == ^group_name,
        select: d.group_name,
        limit: 1

    case Repo.fetch_one(query) do
      {:ok, _} -> true
      _not_found -> false
    end
  end

  defp remove_from_group(keyspace, group_name, encoded_device_id) do
    device_id_result =
      case Device.decode_device_id(encoded_device_id) do
        {:ok, device_id} -> {:ok, device_id}
        {:error, _} -> {:error, :device_not_found}
      end

    with {:ok, device_id} <- device_id_result,
         {:ok, insertion_uuid} <-
           retrieve_group_insertion_uuid(keyspace, group_name, encoded_device_id) do
      delete_group = MapSet.new([group_name])

      device_query =
        from(DataBaseDevice,
          prefix: ^keyspace,
          where: [device_id: ^device_id],
          update: [set: [groups: fragment("groups - ?", ^delete_group)]]
        )

      device_query = Repo.to_sql(:update_all, device_query)

      grouped_device_query =
        from(GroupedDevice,
          prefix: ^keyspace,
          where: [group_name: ^group_name, insertion_uuid: ^insertion_uuid, device_id: ^device_id]
        )

      grouped_device_query = Repo.to_sql(:delete_all, grouped_device_query)

      Exandra.execute_batch(Repo, %Exandra.Batch{queries: [device_query, grouped_device_query]})
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

  def check_all_devices_exist(realm_name, device_ids, group_changeset) do
    keyspace = DataAccessRealm.keyspace_name(realm_name)

    device_ids
    |> Enum.chunk_every(100)
    |> Enum.reduce_while(:ok, fn id_chunk, :ok ->
      existing_ids =
        from(d in DataBaseDevice,
          prefix: ^keyspace,
          where: d.device_id in ^id_chunk,
          select: d.device_id
        )
        |> Repo.all()

      if Enum.count(existing_ids) == Enum.count(id_chunk) do
        {:cont, :ok}
      else
        # Some device_id was not present in the database. Take the first.
        not_found =
          id_chunk
          |> Enum.find(&(&1 not in existing_ids))
          |> Device.encode_device_id()

        group_changeset =
          group_changeset |> Changeset.add_error(:devices, "must exist (#{not_found} not found)")

        {:halt, {:error, group_changeset}}
      end
    end)
  end

  def check_group_exists(realm_name, group_name) do
    keyspace = DataAccessRealm.keyspace_name(realm_name)

    from(GroupedDevice, select: [:group_name], limit: 1)
    |> Repo.fetch_by([group_name: group_name], prefix: keyspace)
  end

  def add_to_grouped_device(realm_name, group_name, decoded_device_ids) do
    keyspace = DataAccessRealm.keyspace_name(realm_name)

    queries =
      decoded_device_ids
      |> Enum.flat_map(fn device_id ->
        insertion_uuid = UUID.uuid1()

        group = %{group_name => insertion_uuid}

        query =
          from(DataBaseDevice, prefix: ^keyspace, where: [device_id: ^device_id])
          |> update([d], set: [groups: fragment("groups + ?", ^group)])

        update_device_groups =
          Repo.to_sql(:update_all, query)

        grouped_device =
          %GroupedDevice{
            group_name: group_name,
            insertion_uuid: insertion_uuid,
            device_id: device_id
          }

        insert_grouped_device = Repo.insert_to_sql(grouped_device, prefix: keyspace)

        [update_device_groups, insert_grouped_device]
      end)

    Exandra.execute_batch(Repo, %Exandra.Batch{queries: queries})
  end

  def list_groups(realm_name) do
    keyspace = DataAccessRealm.keyspace_name(realm_name)

    from(g in GroupedDevice, prefix: ^keyspace, select: g.group_name, distinct: true)
    |> Repo.all()
  end

  def get_group(realm_name, group_name) do
    keyspace = DataAccessRealm.keyspace_name(realm_name)
    group_query = from g in GroupedDevice, select: g.group_name, limit: 1
    fetch_clause = [group_name: group_name]
    opts = [prefix: keyspace, error: :group_not_found]

    with {:ok, group_name} <- Repo.fetch_by(group_query, fetch_clause, opts) do
      {:ok, %Group{group_name: group_name}}
    end
  end
end
