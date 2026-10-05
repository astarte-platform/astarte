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

defmodule Astarte.VMQ.Plugin.DatabaseTestHelper do
  @moduledoc "Sets up and tears down the Cassandra/Scylla `test` keyspace used across the suite."
  alias Astarte.Core.Device
  import ExUnit.Assertions
  alias Astarte.Core.CQLUtils
  alias Astarte.VMQ.Plugin.Config

  @test_keyspace CQLUtils.realm_name_to_keyspace_name("test", Config.astarte_instance_id())

  @create_test_keyspace """
    CREATE KEYSPACE  #{@test_keyspace}
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_devices_table """
  CREATE TABLE #{@test_keyspace}.devices (
    device_id uuid,
    PRIMARY KEY (device_id)
  );
  """

  @create_deletion_in_progress_table """
  CREATE TABLE #{@test_keyspace}.deletion_in_progress (
    device_id uuid,
    vmq_ack boolean,
    PRIMARY KEY (device_id)
  );
  """

  @insert_device_into_devices """
    INSERT INTO #{@test_keyspace}.devices (device_id)
      VALUES (:device_id);
  """

  @insert_device_into_deletion_in_progress """
    INSERT INTO #{@test_keyspace}.deletion_in_progress (device_id, vmq_ack)
      VALUES (:device_id, :vmq_ack);
  """

  @truncate_devices_table """
  TRUNCATE #{@test_keyspace}.devices;
  """

  @truncate_deletion_in_progress_table """
  TRUNCATE #{@test_keyspace}.deletion_in_progress;
  """

  @drop_test_keyspace """
  DROP KEYSPACE #{@test_keyspace};
  """

  def setup_db! do
    Xandra.Cluster.run(:xandra, fn conn ->
      Xandra.execute!(conn, @create_test_keyspace, %{}, consistency: :local_quorum)
      Xandra.execute!(conn, @create_devices_table, %{}, consistency: :local_quorum)
      Xandra.execute!(conn, @create_deletion_in_progress_table, %{}, consistency: :local_quorum)
    end)
  end

  def insert_device_into_devices!(encoded_device_id) do
    Xandra.Cluster.run(:xandra, fn conn ->
      {:ok, device_id} = Device.decode_device_id(encoded_device_id)

      params = %{
        "device_id" => device_id
      }

      prepared = Xandra.prepare!(conn, @insert_device_into_devices)
      Xandra.execute!(conn, prepared, params, consistency: :quorum)
    end)
  end

  def insert_device_into_deletion_in_progress!(encoded_device_id) do
    Xandra.Cluster.run(:xandra, fn conn ->
      {:ok, device_id} = Device.decode_device_id(encoded_device_id)

      params = %{
        "device_id" => device_id,
        "vmq_ack" => false
      }

      prepared = Xandra.prepare!(conn, @insert_device_into_deletion_in_progress)
      Xandra.execute!(conn, prepared, params, consistency: :quorum)
    end)
  end

  def cleanup_db! do
    Xandra.Cluster.run(:xandra, fn conn ->
      Xandra.execute!(conn, @truncate_devices_table, %{}, consistency: :local_quorum)
      Xandra.execute!(conn, @truncate_deletion_in_progress_table, %{}, consistency: :local_quorum)
    end)
  end

  def teardown_db! do
    Xandra.Cluster.run(:xandra, fn conn ->
      {:ok, %Xandra.SchemaChange{}} = Xandra.execute(conn, @drop_test_keyspace)
    end)
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
end
