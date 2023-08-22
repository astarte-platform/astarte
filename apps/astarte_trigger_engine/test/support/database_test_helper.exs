#
# This file is part of Astarte.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule Astarte.TriggerEngine.DatabaseTestHelper do
  require Logger

  alias Astarte.TriggerEngine.Config
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto

  @test_realm "autotestrealm"

  @create_astarte_keyspace """
    CREATE KEYSPACE astarte
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_test_keyspace """
    CREATE KEYSPACE #{@test_realm}
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_realms_table """
  CREATE TABLE astarte.realms (
    realm_name varchar,

    PRIMARY KEY ((realm_name))
  );
  """

  @create_kv_store_table """
    CREATE TABLE #{@test_realm}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
  """

  @insert_policy_into_kv_store """
    INSERT INTO #{@test_realm}.kv_store (group, key, value) VALUES ('trigger_policy', :policy_name, :policy_proto)
  """

  @delete_policy_from_kv_store """
    DELETE FROM #{@test_realm}.kv_store WHERE group = 'trigger_policy' AND key = :policy_name
  """

  @insert_realm """
  INSERT INTO astarte.realms (realm_name) VALUES (:realm_name)
  """

  @drop_astarte_keyspace """
    DROP KEYSPACE astarte
  """

  @drop_test_keyspace """
    DROP KEYSPACE #{@test_realm}
  """

  def create_test_env() do
    {:ok, _result} =
      Xandra.Cluster.execute(:xandra, @create_astarte_keyspace, %{}, consistency: :all)

    {:ok, _result} =
      Xandra.Cluster.execute(:xandra, @create_test_keyspace, %{}, consistency: :all)

    {:ok, _result} = Xandra.Cluster.execute(:xandra, @create_realms_table, %{})
    {:ok, _result} = Xandra.Cluster.execute(:xandra, @create_kv_store_table, %{})

    {:ok, insert_realm} = Xandra.Cluster.prepare(:xandra, @insert_realm)
    {:ok, _result} = Xandra.Cluster.execute(:xandra, insert_realm, %{"realm_name" => @test_realm})
    :ok
  end

  def install_policy(policy) do
    policy_proto =
      policy
      |> Policy.to_policy_proto()
      |> PolicyProto.encode()

    {:ok, prepared} = Xandra.Cluster.prepare(:xandra, @insert_policy_into_kv_store)

    {:ok, _result} =
      Xandra.Cluster.execute(:xandra, prepared, %{
        "policy_name" => policy.name,
        "policy_proto" => policy_proto
      })
  end

  def delete_policy(policy_name) do
    {:ok, prepared} = Xandra.Cluster.prepare(:xandra, @delete_policy_from_kv_store)
    {:ok, _result} = Xandra.Cluster.execute(:xandra, prepared, %{"policy_name" => policy_name})
  end

  def drop_test_env() do
    {:ok, _result} = Xandra.Cluster.execute(:xandra, @drop_astarte_keyspace, %{})
    {:ok, _result} = Xandra.Cluster.execute(:xandra, @drop_test_keyspace, %{})

    :ok
  end

  def test_realm, do: @test_realm

  # TODO: include in astarte_data_access
  def await_cluster_connected(cluster \\ nil, tries \\ 10) do
    cluster = cluster || Config.xandra_options!()[:name]
    fun = &Xandra.execute!(&1, "SELECT * FROM system.local")

    with {:error, %Xandra.ConnectionError{}} <- Xandra.Cluster.run(cluster, _options = [], fun) do
      if tries > 0 do
        Process.sleep(100)
        await_cluster_connected(cluster, tries - 1)
      else
        raise("Connection to the cluster failed")
      end
    end
  end
end
