#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin.Queries do
  @moduledoc "Cassandra/Scylla queries for device existence and deletion status."
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Realm
  alias Astarte.VMQ.Plugin.Config

  @doc """
  Checks whether a device row exists in Astarte database (i.e. it has at least been registered).
  Returns either {:ok, exists?} or {:error, reason}.
  """
  @spec check_if_device_exists(String.t(), Device.device_id()) ::
          {:ok, boolean()}
          | {:error, Xandra.Error.t()}
          | {:error, Xandra.ConnectionError.t()}
          | {:error, :invalid_realm_name}
  def check_if_device_exists(realm, decoded_device_id) do
    Xandra.Cluster.run(:xandra, &do_check_if_device_exists(&1, realm, decoded_device_id))
  end

  defp do_check_if_device_exists(conn, realm, device_id) do
    query = """
    SELECT count(*)
    FROM devices
    WHERE device_id = :device_id
    """

    params = %{
      "device_id" => device_id
    }

    with {:ok, page = %Xandra.Page{}} <-
           execute_query(conn, realm, query, params, consistency: :quorum) do
      [%{"count" => value}] = Enum.to_list(page)
      {:ok, value > 0}
    end
  end

  @doc """
  Checks whether a device is currently being deleted from Astarte.
  Returns either {:ok, is_being_deleted?} or {:error, reason}.
  """
  @spec check_device_deletion_in_progress(String.t(), Device.device_id()) ::
          {:ok, boolean()}
          | {:error, Xandra.Error.t()}
          | {:error, Xandra.ConnectionError.t()}
          | {:error, :invalid_realm_name}
  def check_device_deletion_in_progress(realm, encoded_device_id) do
    Xandra.Cluster.run(
      :xandra,
      &do_check_device_deletion_in_progress(&1, realm, encoded_device_id)
    )
  end

  defp do_check_device_deletion_in_progress(conn, realm, device_id) do
    query = """
    SELECT count(*)
    FROM deletion_in_progress
    WHERE device_id =:device_id
    """

    params = %{
      "device_id" => device_id
    }

    with {:ok, page = %Xandra.Page{}} <-
           execute_query(conn, realm, query, params, consistency: :quorum) do
      [%{"count" => value}] = Enum.to_list(page)
      {:ok, value > 0}
    end
  end

  @doc """
  Writes the VMQ deletion ack to the deletion_in_progress table.
  Returns either {:ok, %Xandra.Void{}} or {:error, reason}.
  """
  @spec ack_device_deletion(String.t(), Device.device_id()) ::
          {:ok, Xandra.Void.t()}
          | {:error, Xandra.Error.t()}
          | {:error, Xandra.ConnectionError.t()}
          | {:error, :invalid_realm_name}
  def ack_device_deletion(realm, device_id) do
    Xandra.Cluster.run(
      :xandra,
      &do_ack_device_deletion(&1, realm, device_id)
    )
  end

  defp do_ack_device_deletion(conn, realm, device_id) do
    query = """
    UPDATE deletion_in_progress
    SET vmq_ack = true
    WHERE device_id = :device_id
    """

    params = %{
      "device_id" => device_id
    }

    execute_query(conn, realm, query, params, consistency: :quorum)
  end

  defp execute_query(conn, realm, query, params, query_opts) do
    with {:ok, prepared} <- prepare_query(conn, realm, query) do
      Xandra.execute(conn, prepared, params, query_opts)
    end
  end

  defp prepare_query(conn, realm, query) do
    with :ok <- use_realm(conn, realm) do
      Xandra.prepare(conn, query)
    end
  end

  defp use_realm(conn, realm) when is_binary(realm) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm, Config.astarte_instance_id())

    with :ok <- verify_realm(realm),
         {:ok, %Xandra.SetKeyspace{}} <- Xandra.execute(conn, "USE #{keyspace_name}") do
      :ok
    end
  end

  defp verify_realm(realm_name) do
    case Realm.valid_name?(realm_name) do
      true -> :ok
      false -> {:error, :invalid_realm_name}
    end
  end
end
