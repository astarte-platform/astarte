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

defmodule Astarte.Housekeeping.Realms.QueriesTest do
  use Astarte.Housekeeping.DataCase, async: true
  use Mimic

  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Helpers.Database
  alias Astarte.Housekeeping.Migrator
  alias Astarte.Housekeeping.Realms
  alias Astarte.Housekeeping.Realms.Queries
  alias Astarte.Housekeeping.Realms.Realm, as: HKRealm

  import Ecto.Query

  @public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt3/eYliAJM2Pj+rChGlY
  nDssZKmqvVqWXAI78tAAr2FhyiD32N8n08YG0nSjGYBnfm/+MIY6A9S+obdUrp7g
  6wKYhVt5YZoCpMhWIvn4E0xkT0I4gNFnuUaAmWoxAWYUUC3wAR3eUuBf4a4LXrhN
  VOj6nbitJ4wJRfkuG9N5jovQTe9kKsrIQag5+ggbq8I87d0ACA/ZHiAxFmSbTSqz
  ObcAESuGolSNfs17mS8NMs93O9Vpo2oVC5xYvdikfhouGcRBmjiU2b5GD+1Hcga9
  68ejTi6XqLjwxSLF8SZ91Uf6ntXIihRcdNXy5DNb1+LLI4d4MwfOmrgnQwb7EA2n
  vQIDAQAB
  -----END PUBLIC KEY-----
  """
  @replication_factor 1
  @datacenter "datacenter1"
  @map_replication_factor %{@datacenter => 1}

  describe "database initialization" do
    setup do
      astarte_instance_id = "another#{System.unique_integer([:positive])}"
      Database.setup_database_access(astarte_instance_id)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Database.teardown_astarte_keyspace()
      end)
    end

    test "returns ok" do
      assert :ok = Queries.initialize_database()
    end

    test "returns ok with NetworkTopologyStrategy" do
      Config
      |> expect(:astarte_keyspace_replication_strategy!, fn -> :network_topology_strategy end)
      |> expect(:astarte_keyspace_network_replication_map!, fn -> @map_replication_factor end)
      |> reject(:astarte_keyspace_replication_factor!, 0)

      assert :ok = Queries.initialize_database()

      astarte_keyspace = Realm.astarte_keyspace_name()

      replication =
        from(k in "system_schema.keyspaces", select: k.replication)
        |> Repo.get_by!(keyspace_name: astarte_keyspace)

      replication_class = replication["class"]
      {datacenter_replication, ""} = replication[@datacenter] |> Integer.parse()

      assert replication_class == "org.apache.cassandra.locator.NetworkTopologyStrategy"
      assert datacenter_replication == @map_replication_factor[@datacenter]
    end

    test "always creates keyspaces where lightweight transactions work" do
      Config
      |> expect(:astarte_keyspace_replication_strategy!, fn -> :network_topology_strategy end)
      |> expect(:astarte_keyspace_network_replication_map!, fn -> @map_replication_factor end)
      |> reject(:astarte_keyspace_replication_factor!, 0)

      astarte_keyspace = Realm.astarte_keyspace_name()

      assert :ok = Queries.initialize_database()
      assert {:ok, _} = Database.lightweight_transaction_check(astarte_keyspace)
    end

    test "defaults to NetworkTopologyStrategy derived from the live Scylla topology when no replication strategy is configured" do
      # When the replication strategy env var is not set, Config returns `nil`
      # and `create_astarte_keyspace/0` is expected to derive the replication
      # map from the actual ScyllaDB network topology, instead of falling back
      # to SimpleStrategy/RF=1. The test cluster has a single node in
      # `datacenter1`, so the resulting map must be %{"datacenter1" => 1} and
      # the keyspace class must be NetworkTopologyStrategy.
      Config
      |> expect(:astarte_keyspace_replication_strategy!, fn -> nil end)
      |> reject(:astarte_keyspace_replication_factor!, 0)
      |> reject(:astarte_keyspace_network_replication_map!, 0)

      assert :ok = Queries.initialize_database()

      astarte_keyspace = Realm.astarte_keyspace_name()

      replication =
        from(k in "system_schema.keyspaces", select: k.replication)
        |> Repo.get_by!(keyspace_name: astarte_keyspace)

      {datacenter_replication, ""} = replication[@datacenter] |> Integer.parse()

      assert replication["class"] == "org.apache.cassandra.locator.NetworkTopologyStrategy"
      assert datacenter_replication == 1
    end

    @tag :inspect_replication
    test "inspects auto-detected replication from live cluster when no strategy is configured" do
      Config
      |> expect(:astarte_keyspace_replication_strategy!, fn -> nil end)
      |> reject(:astarte_keyspace_replication_factor!, 0)
      |> reject(:astarte_keyspace_network_replication_map!, 0)

      assert :ok = Queries.initialize_database()

      astarte_keyspace = Realm.astarte_keyspace_name()

      Migrator.save_default_replication()

      {:ok, replication_map} = Queries.fetch_keyspace_replication()

      replication =
        from(k in "system_schema.keyspaces", select: k.replication)
        |> Repo.get_by!(keyspace_name: astarte_keyspace)

      assert replication["class"] == "org.apache.cassandra.locator.NetworkTopologyStrategy"
      assert replication_map == %{strategy: :network_topology, dc_factors: %{@datacenter => 1}}
    end

    @tag :inspect_replication
    test "inspects replication when simple strategy is configured" do
      Config
      |> expect(:astarte_keyspace_replication_strategy!, fn -> :simple_strategy end)
      |> expect(:astarte_keyspace_replication_factor!, fn -> 1 end)
      |> reject(:astarte_keyspace_network_replication_map!, 0)

      assert :ok = Queries.initialize_database()

      astarte_keyspace = Realm.astarte_keyspace_name()

      Migrator.save_default_replication()

      {:ok, replication_map} = Queries.fetch_keyspace_replication()

      replication =
        from(k in "system_schema.keyspaces", select: k.replication)
        |> Repo.get_by!(keyspace_name: astarte_keyspace)

      assert replication["class"] == "org.apache.cassandra.locator.SimpleStrategy"
      assert replication_map == %{strategy: :simple, factor: 1}
    end

    @tag :inspect_replication
    test "inspects replication when network topology strategy is configured" do
      Config
      |> expect(:astarte_keyspace_replication_strategy!, fn -> :network_topology_strategy end)
      |> reject(:astarte_keyspace_replication_factor!, 0)
      |> expect(:astarte_keyspace_network_replication_map!, fn -> @map_replication_factor end)

      assert :ok = Queries.initialize_database()

      astarte_keyspace = Realm.astarte_keyspace_name()

      Migrator.save_default_replication()

      {:ok, replication_map} = Queries.fetch_keyspace_replication()

      replication =
        from(k in "system_schema.keyspaces", select: k.replication)
        |> Repo.get_by!(keyspace_name: astarte_keyspace)

      assert replication["class"] == "org.apache.cassandra.locator.NetworkTopologyStrategy"
      assert replication_map == %{strategy: :network_topology, dc_factors: %{"datacenter1" => 1}}
    end

    test "returns database error" do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)
      assert {:error, :database_error} = Queries.initialize_database()
    end

    test "returns connection error" do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, :database_connection_error} = Queries.initialize_database()
    end

    test "returns another error" do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, "generic error"} end)
      assert {:error, _} = Queries.initialize_database()
    end
  end

  describe "create a realm," do
    setup %{astarte_instance_id: astarte_instance_id} do
      realm_name = "another#{System.unique_integer([:positive])}"

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Database.teardown_realm_keyspace(realm_name)
      end)

      Database.save_default_replication(%{strategy: :simple, factor: 1})

      %{realm_name: realm_name}
    end

    test "creations returns ok", %{realm_name: realm_name} do
      assert :ok = Queries.create_realm(realm_name, "test1publickey", 1, 1, 1, [])
    end

    test "creations returns ok with nil replication factor", %{realm_name: realm_name} do
      assert :ok = Queries.create_realm(realm_name, "test1publickey", nil, 1, 1, [])
    end

    test "creations returns ok with 0 max retentions factor", %{realm_name: realm_name} do
      assert :ok = Queries.create_realm(realm_name, "test1publickey", 1, 1, 0, [])
    end

    test "creations returns error with bigger than nodes replication factor", %{
      realm_name: realm_name
    } do
      assert {:error,
              {:invalid_replication,
               "replication_factor 10 is >= 1 nodes in datacenter datacenter1"}} =
               Queries.create_realm(realm_name, "test1publickey", 10, 1, 1, [])
    end

    test "creations returns an error", %{realm_name: realm_name} do
      Mimic.stub(Repo, :query, fn _, _, _ -> {:error, "generic error"} end)

      assert {:error, "generic error"} =
               Queries.create_realm(realm_name, "test1publickey", 1, 1, 1, [])
    end
  end

  describe "list/get realm(s)," do
    setup %{astarte_instance_id: astarte_instance_id} do
      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Database.teardown_realm_keyspace("testrealm")
        Database.teardown_realm_keyspace("anotherrealm")
      end)

      Database.setup_realm_keyspace("testrealm")
      :ok
    end

    test "list returns the existing realm" do
      assert {:ok, realms} = Queries.list_realms()
      assert %HKRealm{realm_name: "testrealm"} in realms
    end

    test "list respects new realm creations" do
      assert :ok = Queries.create_realm("anotherrealm", "test2publickey", 1, 1, 1, [])

      assert {:ok, realms} = Queries.list_realms()
      assert %HKRealm{realm_name: "testrealm"} in realms
      assert %HKRealm{realm_name: "anotherrealm"} in realms
    end

    test "get returns the realm data just inserted" do
      assert :ok = Queries.create_realm("anotherrealm", "test2publickey", 1, 1, 1, [])

      assert {:ok,
              %{
                replication_factor: 1,
                datastream_maximum_storage_retention: 1,
                device_registration_limit: 1,
                jwt_public_key_pem: "test2publickey",
                realm_name: "anotherrealm",
                replication_class: "SimpleStrategy"
              }} = Queries.get_realm("anotherrealm")
    end

    test "get returns error due to get_public_key error" do
      assert :ok = Queries.create_realm("anotherrealm", "test2publickey", 1, 1, 1, [])
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert {:error, :database_connection_error} =
               Queries.get_realm("anotherrealm")
    end

    test "get returns the realm data just inserted, with a different replication class" do
      assert :ok =
               Queries.create_realm(
                 "anotherrealm",
                 "test2publickey",
                 %{"datacenter1" => 1},
                 1,
                 1,
                 []
               )

      assert {:ok,
              %{
                datastream_maximum_storage_retention: 1,
                device_registration_limit: 1,
                jwt_public_key_pem: "test2publickey",
                realm_name: "anotherrealm",
                replication_class: "NetworkTopologyStrategy",
                datacenter_replication_factors: %{"datacenter1" => 1}
              }} = Queries.get_realm("anotherrealm")
    end

    test "get returns error due to inconsistent db data" do
      # testrealm does not have a public key saved

      assert {:error, :public_key_not_found} = Queries.get_realm("testrealm")
    end

    test "get returns error due to not existent db data" do
      # testrealm does not have a public key saved

      assert {:error, :realm_not_found} = Queries.get_realm("fakerealm")
    end

    test "returns database error" do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: ""}} end)
      assert {:error, :database_error} = Queries.list_realms()
    end

    test "returns connection error" do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, :database_connection_error} = Queries.list_realms()
    end
  end

  describe "realm_existing?/1" do
    test "returns {:ok, true} when the realm exists", %{realm_name: realm_name} do
      assert {:ok, true} = Queries.realm_existing?(realm_name)
    end

    test "returns {:ok, false} when the realm does not exist" do
      assert {:ok, false} = Queries.realm_existing?("nonexisting")
    end

    test "returns {:error, _} when there is a database connection error", %{
      realm_name: realm_name
    } do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, _} = Queries.realm_existing?(realm_name)
    end
  end

  describe "set device registration limit" do
    setup %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} do
      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Queries.set_datastream_maximum_storage_retention(realm_name, 50)
        Queries.set_device_registration_limit(realm_name, 500)
        Database.insert_public_key(realm_name)
      end)

      other_realm_name = "realm#{System.unique_integer([:positive])}"
      %{other_realm_name: other_realm_name}
    end

    test "set limit returns ok ", %{realm_name: realm_name} do
      assert :ok = Queries.set_device_registration_limit(realm_name, 10)

      assert {:ok, %{device_registration_limit: 10, realm_name: ^realm_name}} =
               Queries.get_realm(realm_name)
    end

    test "set limit fails due to db error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)
      assert_raise Xandra.Error, fn -> Queries.set_device_registration_limit(realm_name, 10) end
    end

    test "set limit fails due to db connection error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.set_device_registration_limit(realm_name, 10)
      end
    end
  end

  describe "delete device registration limit" do
    setup %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} do
      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Queries.set_datastream_maximum_storage_retention(realm_name, 50)
        Queries.set_device_registration_limit(realm_name, 500)
        Database.insert_public_key(realm_name)
      end)

      other_realm_name = "realm#{System.unique_integer([:positive])}"
      %{other_realm_name: other_realm_name}
    end

    setup %{realm_name: realm_name} do
      Queries.set_device_registration_limit(realm_name, 10)
      :ok
    end

    test "delete limit returns ok ", %{realm_name: realm_name} do
      assert :ok = Queries.delete_device_registration_limit(realm_name)

      assert {:ok,
              %{
                device_registration_limit: nil,
                realm_name: ^realm_name
              }} = Queries.get_realm(realm_name)
    end

    test "fails due to db error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)
      assert_raise Xandra.Error, fn -> Queries.delete_device_registration_limit(realm_name) end
    end

    test "fails due to db connection error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.delete_device_registration_limit(realm_name)
      end
    end
  end

  describe "set storage retention" do
    setup %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} do
      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Queries.set_datastream_maximum_storage_retention(realm_name, 50)
        Queries.set_device_registration_limit(realm_name, 500)
        Database.insert_public_key(realm_name)
      end)

      other_realm_name = "realm#{System.unique_integer([:positive])}"
      %{other_realm_name: other_realm_name}
    end

    test "returns ok ", %{realm_name: realm_name} do
      assert :ok = Queries.set_datastream_maximum_storage_retention(realm_name, 10)

      assert {:ok,
              %{
                datastream_maximum_storage_retention: 10,
                realm_name: ^realm_name
              }} = Queries.get_realm(realm_name)
    end

    test "returns ok using 0", %{realm_name: realm_name} do
      assert :ok = Queries.set_datastream_maximum_storage_retention(realm_name, 0)

      assert {:ok,
              %{
                datastream_maximum_storage_retention: 0,
                realm_name: ^realm_name
              }} = Queries.get_realm(realm_name)
    end

    test "fails due to db error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)

      assert_raise Xandra.Error, fn ->
        Queries.set_datastream_maximum_storage_retention(realm_name, 10)
      end
    end

    test "fails due to db connection error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.set_datastream_maximum_storage_retention(realm_name, 10)
      end
    end
  end

  describe "delete storage retention" do
    setup %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} do
      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Queries.set_datastream_maximum_storage_retention(realm_name, 50)
        Queries.set_device_registration_limit(realm_name, 500)
        Database.insert_public_key(realm_name)
      end)

      other_realm_name = "realm#{System.unique_integer([:positive])}"
      %{other_realm_name: other_realm_name}
    end

    setup %{realm_name: realm_name} do
      Queries.set_datastream_maximum_storage_retention(realm_name, 10)
      :ok
    end

    test "returns ok ", %{realm_name: realm_name} do
      assert :ok = Queries.delete_datastream_maximum_storage_retention(realm_name)

      assert {:ok,
              %{
                datastream_maximum_storage_retention: nil,
                realm_name: ^realm_name
              }} = Queries.get_realm(realm_name)
    end

    test "fails due to db error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)

      assert_raise Xandra.Error, fn ->
        Queries.delete_datastream_maximum_storage_retention(realm_name)
      end
    end

    test "fails due to db connection error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.delete_datastream_maximum_storage_retention(realm_name)
      end
    end
  end

  describe "update public key" do
    setup %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} do
      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Queries.set_datastream_maximum_storage_retention(realm_name, 50)
        Queries.set_device_registration_limit(realm_name, 500)
        Database.insert_public_key(realm_name)
      end)

      other_realm_name = "realm#{System.unique_integer([:positive])}"
      %{other_realm_name: other_realm_name}
    end

    test "returns ok ", %{realm_name: realm_name} do
      assert :ok = Queries.update_public_key(realm_name, "newPublicKey")

      assert {:ok,
              %{
                jwt_public_key_pem: "newPublicKey",
                realm_name: ^realm_name
              }} = Queries.get_realm(realm_name)
    end

    test "fails due to db error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)

      assert_raise Xandra.Error, fn ->
        Queries.update_public_key(realm_name, "newPublicKey")
      end
    end

    test "fails due to db connection error", %{realm_name: realm_name} do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.update_public_key(realm_name, "newPublicKey")
      end
    end
  end

  describe "realm creation" do
    setup %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} do
      other_realm_name = "realm#{System.unique_integer([:positive])}"

      {:ok, live_topology} = Queries.fetch_network_topology()
      Database.save_default_replication(%{strategy: :network_topology, dc_factors: live_topology})

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Queries.set_datastream_maximum_storage_retention(realm_name, 50)
        Queries.set_device_registration_limit(realm_name, 500)
        Database.teardown_realm_keyspace(other_realm_name)
        Database.insert_public_key(realm_name)
      end)

      %{other_realm_name: other_realm_name}
    end

    test "CreateRealm with nil realm" do
      assert {:error, %Ecto.Changeset{}} =
               Realms.create_realm(%{realm_name: nil, jwt_public_key_pem: @public_key_pem})
    end

    test "CreateRealm success", %{other_realm_name: realm_name} do
      assert {:ok, _} =
               Realms.create_realm(%{realm_name: realm_name, jwt_public_key_pem: @public_key_pem})
    end

    test "CreateRealm with nil public key" do
      assert {:error, %Ecto.Changeset{}} =
               Realms.create_realm(%{realm_name: nil, jwt_public_key_pem: nil})
    end

    test "CreateRealm with invalid realm_name" do
      assert {:error, %Ecto.Changeset{}} =
               Realms.create_realm(%{realm_name: "realm_not_allowed", jwt_public_key_pem: nil})
    end

    test "realm creation successful with nil replication", %{other_realm_name: realm_name} do
      assert {:ok, _} =
               Realms.create_realm(%{
                 realm_name: realm_name,
                 jwt_public_key_pem: @public_key_pem,
                 replication_factor: nil
               })
    end

    test "realm created without explicit replication inherits NetworkTopologyStrategy from astarte keyspace",
         %{
           other_realm_name: realm_name
         } do
      assert {:ok, _} =
               Realms.create_realm(%{
                 realm_name: realm_name,
                 jwt_public_key_pem: @public_key_pem
               })

      assert {:ok, realm} = Queries.get_realm(realm_name)

      assert realm.replication_class == "NetworkTopologyStrategy"
      assert map_size(realm.datacenter_replication_factors) > 0
    end

    @tag :inspect_replication
    test "realm created without explicit replication inherits replication matching live cluster topology",
         %{other_realm_name: realm_name} do
      assert {:ok, live_topology} = Queries.fetch_network_topology()

      assert {:ok, _} =
               Realms.create_realm(%{
                 realm_name: realm_name,
                 jwt_public_key_pem: @public_key_pem
               })

      assert {:ok, realm} = Queries.get_realm(realm_name)

      assert realm.replication_class == "NetworkTopologyStrategy"

      for {dc, node_count} <- live_topology do
        assert realm.datacenter_replication_factors[dc] == node_count,
               "expected #{dc} replication_factor=#{node_count} (nodes in DC), got #{realm.datacenter_replication_factors[dc]}"
      end
    end

    test "Realm creation succeeds when device_registration_limit is nil", %{
      other_realm_name: realm_name
    } do
      assert {:ok, _} =
               Realms.create_realm(%{
                 realm_name: realm_name,
                 jwt_public_key_pem: @public_key_pem,
                 device_registration_limit: nil
               })
    end

    test "Realm creation successful with explicit SimpleStrategy replication", %{
      other_realm_name: realm_name
    } do
      assert {:ok, _} =
               Realms.create_realm(%{
                 realm_name: realm_name,
                 jwt_public_key_pem: @public_key_pem,
                 replication_factor: @replication_factor
               })
    end

    test "realm creation successful with explicit NetworkTopologyStrategy replication", %{
      other_realm_name: realm_name
    } do
      assert {:ok, _} =
               Realms.create_realm(%{
                 realm_name: realm_name,
                 jwt_public_key_pem: @public_key_pem,
                 replication_class: "NetworkTopologyStrategy",
                 datacenter_replication_factors: %{"datacenter1" => 1}
               })
    end

    test "realm creation fails with invalid SimpleStrategy replication", %{
      other_realm_name: realm_name
    } do
      assert {:error,
              {:invalid_replication,
               "replication_factor 9 is >= 1 nodes in datacenter datacenter1"}} =
               Realms.create_realm(%{
                 realm_name: realm_name,
                 jwt_public_key_pem: @public_key_pem,
                 replication_class: "SimpleStrategy",
                 replication_factor: 9
               })
    end

    test "realm creation fails with invalid NetworkTopologyStrategy replication", %{
      other_realm_name: realm_name
    } do
      assert {:error, %Ecto.Changeset{}} =
               Realms.create_realm(%{
                 realm_name: realm_name,
                 jwt_public_key_pem: @public_key_pem,
                 replication_class: "NetworkTopologyStrategy",
                 datacenter_replication_factors: [{"imaginarydatacenter", 3}]
               })
    end
  end

  describe "get_keyspace_replication/2" do
    test "returns simple strategy replication factor" do
      keyspace = "test_simple_ks"

      mock_replication = %{
        "class" => "org.apache.cassandra.locator.SimpleStrategy",
        "replication_factor" => "3"
      }

      expect(Repo, :safe_fetch_one, fn _query, _opts ->
        {:ok, mock_replication}
      end)

      assert {:ok, %{strategy: :simple, factor: 3}} =
               Queries.get_keyspace_replication(keyspace)
    end

    test "returns network topology strategy factors" do
      keyspace = "test_network_ks"

      mock_replication = %{
        "class" => "org.apache.cassandra.locator.NetworkTopologyStrategy",
        "dc1" => "3",
        "dc2" => "2"
      }

      expect(Repo, :safe_fetch_one, fn _query, _opts ->
        {:ok, mock_replication}
      end)

      assert {:ok, %{strategy: :network_topology, dc_factors: factors}} =
               Queries.get_keyspace_replication(keyspace)

      assert factors == %{"dc1" => 3, "dc2" => 2}
    end

    test "returns error for non-existent keyspace" do
      expect(Repo, :safe_fetch_one, fn _query, _opts ->
        {:error, :not_found}
      end)

      assert {:error, :keyspace_not_found} =
               Queries.get_keyspace_replication("missing_ks")
    end

    test "returns error for unknown replication strategy" do
      mock_replication = %{
        "class" => "org.apache.cassandra.locator.LocalStrategy"
      }

      expect(Repo, :safe_fetch_one, fn _query, _opts ->
        {:ok, mock_replication}
      end)

      assert {:error, {:unknown_strategy, "org.apache.cassandra.locator.LocalStrategy"}} =
               Queries.get_keyspace_replication("local_ks")
    end

    test "handles database error gracefully" do
      expect(Repo, :safe_fetch_one, fn _query, _opts ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} =
               Queries.get_keyspace_replication("any_ks")
    end
  end

  describe "save_keyspace_replication/1" do
    test "saves and retrieves simple strategy replication" do
      replication = %{strategy: :simple, factor: 2}
      assert :ok = Queries.save_keyspace_replication(replication)
      assert {:ok, ^replication} = Queries.fetch_keyspace_replication()
    end

    test "saves and retrieves network topology strategy replication" do
      replication = %{strategy: :network_topology, dc_factors: %{"datacenter1" => 1}}
      assert :ok = Queries.save_keyspace_replication(replication)
      assert {:ok, ^replication} = Queries.fetch_keyspace_replication()
    end
  end

  describe "fetch_keyspace_replication/0" do
    test "returns error when replication has not been saved" do
      Mimic.stub(Astarte.DataAccess.KvStore, :fetch_value, fn _, _, _, _ ->
        {:error, :replication_not_found}
      end)

      assert {:error, :replication_not_found} = Queries.fetch_keyspace_replication()
    end

    test "returns error when stored replication data is corrupted" do
      Mimic.stub(Astarte.DataAccess.KvStore, :fetch_value, fn _, _, _, _ ->
        {:ok, <<0xFF, 0x00, 0xAB>>}
      end)

      assert {:error, :corrupted_replication_data} = Queries.fetch_keyspace_replication()
    end

    test "returns successfully stored replication after save" do
      replication = %{strategy: :simple, factor: 1}
      :ok = Queries.save_keyspace_replication(replication)
      assert {:ok, ^replication} = Queries.fetch_keyspace_replication()
    end
  end

  describe "fetch_network_topology/0" do
    test "returns ok with a map of datacenters to node counts" do
      assert {:ok, topology} = Queries.fetch_network_topology()
      assert is_map(topology)
      assert Map.has_key?(topology, "datacenter1")
    end
  end
end
