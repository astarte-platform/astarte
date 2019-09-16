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
  alias Astarte.AppEngine.API.Groups.Group
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
      query = "SELECT DISTINCT group_name FROM :realm.grouped_devices"

      with {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
           {:ok, %Xandra.Page{} = page} <- Xandra.execute(conn, prepared) do
        {:ok, Enum.map(page, fn %{"group_name" => group_name} -> group_name end)}
      else
        {:error, reason} ->
          Logger.warn("list_groups error: #{inspect(reason)}")
          {:error, :database_error}
      end
    end)
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
    query = "SELECT device_id FROM :realm.devices WHERE device_id = :device_id"

    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"device_id" => device_id}),
         [_device_id] <- Enum.to_list(page) do
      true
    else
      {:error, reason} ->
        Logger.warn("device_exists? returned an error: #{inspect(reason)}")
        false

      [] ->
        false
    end
  end

  defp group_exists?(conn, realm_name, group_name) do
    query = "SELECT group_name FROM :realm.grouped_devices WHERE group_name = :group_name"

    with {:ok, prepared} <- prepare_with_realm(conn, realm_name, query),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"group_name" => group_name}),
         [%{"group_name" => ^group_name} | _] <- Enum.to_list(page) do
      true
    else
      {:error, reason} ->
        Logger.warn("device_exists? returned an error: #{inspect(reason)}")
        false

      [] ->
        false
    end
  end

  defp add_to_group(conn, realm_name, group_name, devices) do
    device_query = """
      UPDATE :realm.devices
      SET groups = groups + :group_map
      WHERE device_id = :device_id
    """

    grouped_devices_query = """
      INSERT INTO :realm.grouped_devices
      (group_name, insertion_time, device_id)
      VALUES
      (:group_name, :insertion_time, :device_id)
    """

    with {:ok, device_prepared} <- prepare_with_realm(conn, realm_name, device_query),
         {:ok, grouped_devices_prepared} <-
           prepare_with_realm(conn, realm_name, grouped_devices_query) do
      {batch, _uuid_state} =
        Enum.reduce(devices, {Xandra.Batch.new(), :uuid.new(self())}, fn encoded_device_id,
                                                                         {batch, uuid_state} ->
          # We can be sure that this succeeds since it was validated in `check_all_devices_exist`
          {:ok, device_id} = Device.decode_device_id(encoded_device_id)

          # TODO: in the future we probably want to check that this generated insertion_time
          # is greater than the last insertion_time in the grouped_devices column
          {insertion_time, new_uuid_state} = :uuid.get_v1(uuid_state)

          group_map = %{group_name => insertion_time}

          new_batch =
            batch
            |> Xandra.Batch.add(device_prepared, %{
              "group_map" => group_map,
              "device_id" => device_id
            })
            |> Xandra.Batch.add(grouped_devices_prepared, %{
              "group_name" => group_name,
              "insertion_time" => insertion_time,
              "device_id" => device_id
            })

          {new_batch, new_uuid_state}
        end)

      case Xandra.execute(conn, batch) do
        {:ok, %Xandra.Void{}} ->
          :ok

        {:error, reason} ->
          Logger.warn("add_to_group error: #{inspect(reason)}")
          {:error, :database_error}
      end
    end
  end

  defp prepare_with_realm(conn, realm_name, query) do
    with {:valid, true} <- {:valid, Realm.valid_name?(realm_name)},
         query_with_realm = String.replace(query, ":realm", realm_name),
         {:ok, prepared} <- Xandra.prepare(conn, query_with_realm) do
      {:ok, prepared}
    else
      {:valid, false} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.warn("prepare_with_realm error: #{inspect(reason)}")
        {:error, :database_error}
    end
  end
end
