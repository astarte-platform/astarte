#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin.Test.Helpers.Database do
  @moduledoc "Test helpers for creating a realm keyspace and inserting/inspecting devices in it."
  alias Astarte.Core.Device
  import ExUnit.Assertions
  alias Astarte.Core.CQLUtils
  alias Astarte.VMQ.Plugin.Config

  @create_test_keyspace """
    CREATE KEYSPACE  :keyspace
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_devices_table """
  CREATE TABLE :keyspace.devices (
    device_id uuid,
    PRIMARY KEY (device_id)
  );
  """

  @create_deletion_in_progress_table """
  CREATE TABLE :keyspace.deletion_in_progress (
    device_id uuid,
    vmq_ack boolean,
    PRIMARY KEY (device_id)
  );
  """

  @insert_device_into_devices """
    INSERT INTO :keyspace.devices (device_id)
      VALUES (:device_id);
  """

  @insert_device_into_deletion_in_progress """
    INSERT INTO :keyspace.deletion_in_progress (device_id, vmq_ack)
      VALUES (:device_id, :vmq_ack);
  """

  @select_device_vmq_ack """
  SELECT vmq_ack
    FROM :keyspace.deletion_in_progress
    WHERE device_id = :device_id;
  """

  @truncate_devices_table """
  TRUNCATE :keyspace.devices;
  """

  @truncate_deletion_in_progress_table """
  TRUNCATE :keyspace.deletion_in_progress;
  """

  @drop_test_keyspace """
  DROP KEYSPACE :keyspace;
  """

  def setup!(realm) do
    keyspace = keyspace_name!(realm)
    execute!(keyspace, @create_test_keyspace)
    execute!(keyspace, @create_devices_table)
    execute!(keyspace, @create_deletion_in_progress_table)
  end

  def insert_device_into_devices!(realm, encoded_device_id) do
    keyspace = keyspace_name!(realm)
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)
    params = %{"device_id" => {"uuid", device_id}}

    execute!(keyspace, @insert_device_into_devices, params)
  end

  def insert_device_into_deletion_in_progress!(realm, encoded_device_id) do
    keyspace = keyspace_name!(realm)
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)
    params = %{"device_id" => {"uuid", device_id}, "vmq_ack" => {"boolean", false}}

    execute!(keyspace, @insert_device_into_deletion_in_progress, params)
  end

  def retrieve_device_vmq_ack!(realm, encoded_device_id) do
    keyspace = keyspace_name!(realm)
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)
    params = %{"device_id" => {"uuid", device_id}}

    page = execute!(keyspace, @select_device_vmq_ack, params)
    [%{"vmq_ack" => vmq_ack?}] = Enum.to_list(page)
    vmq_ack?
  end

  def cleanup_db!(realm) do
    keyspace = keyspace_name!(realm)
    execute!(keyspace, @truncate_devices_table)
    execute!(keyspace, @truncate_deletion_in_progress_table)
  end

  def teardown!(realm) do
    keyspace = keyspace_name!(realm)
    execute!(keyspace, @drop_test_keyspace)
  end

  def await_xandra_cluster_connected!(tries \\ 10) do
    case Xandra.Cluster.run(:xandra, &Xandra.execute(&1, "SELECT * FROM system.local")) do
      {:error, %Xandra.ConnectionError{}} ->
        if tries > 0 do
          Process.sleep(100)
          await_xandra_cluster_connected!(tries - 1)
        else
          flunk("exceeded maximum number of attempts")
        end

      _other ->
        :ok
    end
  end

  defp execute!(keyspace, query, params \\ %{}, opts \\ []) do
    q = String.replace(query, ":keyspace", keyspace)
    Xandra.Cluster.execute!(:xandra, q, params, opts)
  end

  defp keyspace_name!(realm_name) do
    CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id())
  end
end
