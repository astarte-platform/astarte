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

defmodule Astarte.AppEngine.API.Groups do
  @moduledoc """
  The groups context
  """

  alias Astarte.AppEngine.API.Device.DevicesListOptions
  alias Astarte.AppEngine.API.Groups.Group
  alias Astarte.AppEngine.API.Groups.Queries
  alias Astarte.Core.Device

  alias Astarte.AppEngine.API.Realm
  alias Astarte.AppEngine.API.Devices.Device, as: DatabaseDevice
  alias Astarte.AppEngine.API.Groups.GroupedDevice
  alias Astarte.AppEngine.API.Repo
  alias Ecto.Changeset

  import Ecto.Query

  @default_list_limit 1000

  def create_group(realm_name, params) do
    keyspace = Realm.keyspace_name(realm_name)

    group_changeset =
      %Group{}
      |> Group.changeset(params)

    with {:ok, group} <- Changeset.apply_action(group_changeset, :insert),
         {:ok, decoded_device_ids} <- decode_device_ids(group.devices),
         :ok <- check_all_devices_exist(keyspace, decoded_device_ids, group_changeset),
         :ok <- check_group_does_not_exist(keyspace, group.group_name),
         :ok <- add_to_group(keyspace, group.group_name, decoded_device_ids) do
      {:ok, group}
    end
  end

  def list_groups(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    from(g in GroupedDevice, prefix: ^keyspace, select: g.group_name, distinct: true)
    |> Repo.all()
  end

  def get_group(realm_name, group_name) do
    keyspace = Realm.keyspace_name(realm_name)

    group_query = from g in GroupedDevice, select: g.group_name, limit: 1
    fetch_clause = [group_name: group_name]
    opts = [prefix: keyspace, error: :group_not_found]

    with {:ok, group_name} <- Repo.fetch_by(group_query, fetch_clause, opts) do
      {:ok, %Group{group_name: group_name}}
    end
  end

  def list_detailed_devices(realm_name, group_name, params \\ %{}) do
    changeset = DevicesListOptions.changeset(%DevicesListOptions{}, params)

    with {:ok, options} <- Ecto.Changeset.apply_action(changeset, :insert) do
      opts =
        options
        |> Map.from_struct()
        |> Enum.to_list()

      Queries.list_devices(realm_name, group_name, opts)
    end
  end

  def list_devices(realm_name, group_name, params \\ %{}) do
    # We don't use DevicesListOptions.changeset here since from_token
    # is a string in this case
    types = %{from_token: :string, details: :boolean, limit: :integer}

    changeset =
      {%DevicesListOptions{}, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))
      |> Ecto.Changeset.validate_change(:from_token, fn :from_token, token ->
        is_uuid? =
          token
          |> to_charlist()
          |> :uuid.string_to_uuid()
          |> :uuid.is_v1()

        if is_uuid? do
          []
        else
          [from_token: "is invalid"]
        end
      end)

    with {:ok, options} <- Ecto.Changeset.apply_action(changeset, :insert) do
      opts =
        options
        |> Map.from_struct()
        |> Map.put_new(:limit, @default_list_limit)
        |> Enum.to_list()

      Queries.list_devices(realm_name, group_name, opts)
    end
  end

  def add_device(realm_name, group_name, params) do
    types = %{device_id: :string}

    changeset =
      {%{}, types}
      |> Ecto.Changeset.cast(params, [:device_id])
      |> Ecto.Changeset.validate_change(:device_id, fn :device_id, device_id ->
        case Device.decode_device_id(device_id) do
          {:ok, _decoded} -> []
          {:error, _reason} -> [device_id: "is not a valid device id"]
        end
      end)

    Queries.add_device(realm_name, group_name, changeset)
  end

  def remove_device(realm_name, group_name, device_id) do
    Queries.remove_device(realm_name, group_name, device_id)
  end

  def check_device_in_group(realm_name, group_name, device_id) do
    Queries.check_device_in_group(realm_name, group_name, device_id)
  end

  defp check_group_exists(keyspace, group_name) do
    from(GroupedDevice, select: [:group_name], limit: 1)
    |> Repo.fetch_by([group_name: group_name], prefix: keyspace)
  end

  defp check_group_does_not_exist(keyspace, group_name) do
    check_group_exists(keyspace, group_name)
    |> case do
      {:error, _} ->
        :ok

      {:ok, _} ->
        {:error, :group_already_exists}
    end
  end

  defp check_all_devices_exist(keyspace, device_ids, group_changeset) do
    device_ids
    |> Enum.chunk_every(100)
    |> Enum.reduce_while(:ok, fn id_chunk, :ok ->
      existing_ids =
        from(d in DatabaseDevice,
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

  defp decode_device_ids(encoded_device_ids) do
    {decoded_ids, errors} =
      encoded_device_ids
      |> Enum.map(&Device.decode_device_id/1)
      |> Enum.split_with(fn {result, _} -> result == :ok end)

    case errors do
      [] -> {:ok, Enum.map(decoded_ids, fn {:ok, id} -> id end)}
      [first_error | _] -> first_error
    end
  end

  defp add_to_group(keyspace, group_name, decoded_device_ids) do
    grouped_device_table = GroupedDevice.__schema__(:source)

    insert_grouped_device_sql = """
      INSERT INTO #{keyspace}.#{grouped_device_table} (group_name, insertion_uuid, device_id)
      values (?, ?, ?)
    """

    queries =
      decoded_device_ids
      |> Enum.flat_map(fn device_id ->
        insertion_uuid = UUID.uuid1()

        group = %{group_name => insertion_uuid}

        query =
          from(DatabaseDevice, prefix: ^keyspace, where: [device_id: ^device_id])
          |> update([d], set: [groups: fragment("groups + ?", ^group)])

        update_device_groups =
          Repo.to_sql(:update_all, query)

        insert_grouped_device_params = [group_name, insertion_uuid, device_id]
        insert_grouped_device = {insert_grouped_device_sql, insert_grouped_device_params}

        [update_device_groups, insert_grouped_device]
      end)

    Exandra.execute_batch(Repo, %Exandra.Batch{queries: queries})
  end
end
