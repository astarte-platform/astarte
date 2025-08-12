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

  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.Housekeeping.Helpers.Database
  alias Astarte.Housekeeping.Realms
  alias Astarte.Housekeeping.Realms.Queries
  alias Astarte.Housekeeping.Config
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
  describe "database inizialization" do
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

  describe "astarte_keyspace_existing?/0," do
    setup do
      astarte_instance_id = "another#{System.unique_integer([:positive])}"
      Database.setup_database_access(astarte_instance_id)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Database.teardown_astarte_keyspace()
      end)

      %{astarte_instance_id: astarte_instance_id}
    end

    test "true" do
      assert :ok = Queries.initialize_database()
      assert {:ok, true} = Queries.astarte_keyspace_existing?()
    end

    test "false" do
      assert {:ok, false} = Queries.astarte_keyspace_existing?()
    end

    test "fails due to db error" do
      Mimic.expect(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: ""}} end)
      assert {:error, :database_error} = Queries.astarte_keyspace_existing?()
    end

    test "fails due to db connection error" do
      Mimic.expect(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, :database_connection_error} = Queries.astarte_keyspace_existing?()
    end
  end

  describe "create a realm," do
    setup %{astarte_instance_id: astarte_instance_id} do
      realm_name = "another#{System.unique_integer([:positive])}"

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Database.teardown_realm_keyspace(realm_name)
      end)

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

    test "async creations returns ok", %{realm_name: realm_name} do
      assert :ok = Queries.create_realm(realm_name, "test1publickey", 1, 1, 1, async: true)
      Process.sleep(1000)
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
      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Queries.set_datastream_maximum_storage_retention(realm_name, 50)
        Queries.set_device_registration_limit(realm_name, 500)
        Database.insert_public_key(realm_name)
      end)

      other_realm_name = "realm#{System.unique_integer([:positive])}"
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
end
