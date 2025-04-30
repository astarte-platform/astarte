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

defmodule Astarte.Housekeeping.EngineTest do
  use ExUnit.Case
  doctest Astarte.Housekeeping.Engine

  alias Astarte.Housekeeping.Engine
  alias Astarte.Housekeeping.Queries
  alias Astarte.RPC.Protocol.Housekeeping.UpdateRealm
  alias Astarte.Housekeeping.Helpers.Database
  use Mimic

  describe "create a realm," do
    setup do
      realm_name = Astarte.Core.Generators.Realm.realm_name() |> Enum.at(0)

      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
        Database.destroy_test_keyspace!(:xandra, realm_name)
      end)

      Queries.initialize_database()
      {:ok, %{realm_name: realm_name}}
    end

    test "creations returns ok", %{realm_name: realm_name} do
      assert :ok = Engine.create_realm(realm_name, "test1publickey", 1, 1, 1, [])
    end

    test "creations returns ok with nil replication factor", %{realm_name: realm_name} do
      assert :ok = Engine.create_realm(realm_name, "test1publickey", nil, 1, 1, [])
    end

    test "creations returns ok with 0 max retentions factor", %{realm_name: realm_name} do
      assert :ok = Engine.create_realm(realm_name, "test1publickey", 1, 1, 0, [])
    end

    test "creations returns error with bigger than nodes replication factor", %{
      realm_name: realm_name
    } do
      assert {:error, {:invalid_replication, error_message}} =
               Engine.create_realm("testrealm", "test1publickey", 10, 1, 1, [])

      assert error_message =~ ">="
    end

    test "async creations returns ok", %{realm_name: realm_name} do
      on_exit(fn ->
        Process.sleep(1000)
        Database.destroy_test_keyspace!(:xandra, "testrealm")
      end)

      assert :ok = Engine.create_realm(realm_name, "test1publickey", 1, 1, 1, async: true)
    end

    test "fails in case of db error", %{realm_name: realm_name} do
      Xandra.Cluster |> stub(:run, fn _, _, _ -> {:error, "generic error"} end)

      assert {:error, "generic error"} =
               Engine.create_realm(realm_name, "test1publickey", 1, 1, 1, [])

      Database.destroy_test_astarte_keyspace!(:xandra)
    end
  end

  describe "delete a realm," do
    setup do
      realm_name = Astarte.Core.Generators.Realm.realm_name() |> Enum.at(0)

      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
        Database.destroy_test_keyspace!(:xandra, realm_name)
      end)

      Database.setup!(realm_name)
      %{realm_name: realm_name}
    end

    test "deletions returns ok", %{realm_name: realm_name} do
      assert :ok = Engine.delete_realm(realm_name, [])
    end

    test "async deletions returns ok", %{realm_name: realm_name} do
      on_exit(fn ->
        Process.sleep(1000)
        Database.destroy_test_astarte_keyspace!(:xandra)
      end)

      assert :ok = Engine.delete_realm(realm_name, async: true)
    end

    test "fails in case of db error", %{realm_name: realm_name} do
      Xandra.Cluster |> stub(:run, fn _, _, _ -> {:error, "generic error"} end)

      assert {:error, "generic error"} =
               Engine.delete_realm(realm_name)

      Database.destroy_test_astarte_keyspace!(:xandra)
    end
  end

  describe "Realm update" do
    setup do
      realm_name = Astarte.Core.Generators.Realm.realm_name() |> Enum.at(0)

      on_exit(fn ->
        Database.teardown!(realm_name)
      end)

      Queries.initialize_database()
      :ok = Engine.create_realm(realm_name, "test1publickey", 1, 1, 1, [])

      %{realm_name: realm_name}
    end

    test "succeeds when realm exists and valid update values are given", %{realm_name: realm_name} do
      new_public_key = "new_public_key"

      update_values = %UpdateRealm{
        realm: realm_name,
        jwt_public_key_pem: new_public_key
      }

      assert {:ok,
              %{
                realm_name: ^realm_name,
                jwt_public_key_pem: ^new_public_key,
                device_registration_limit: 1,
                datastream_maximum_storage_retention: 1
              }} = Engine.update_realm(realm_name, update_values)
    end

    test "succeeds when realm exists and empty update values are given", %{realm_name: realm_name} do
      update_values = %UpdateRealm{
        realm: realm_name
      }

      assert {:ok,
              %{
                realm_name: ^realm_name,
                jwt_public_key_pem: "test1publickey",
                device_registration_limit: 1,
                datastream_maximum_storage_retention: 1
              }} = Engine.update_realm(realm_name, update_values)
    end

    test "succeeds when realm exists and device_registration_limit is updated", %{
      realm_name: realm_name
    } do
      new_limit = 100

      update_values = %UpdateRealm{
        device_registration_limit: new_limit
      }

      assert {:ok,
              %{
                realm_name: ^realm_name,
                device_registration_limit: ^new_limit
              }} = Engine.update_realm(realm_name, update_values)
    end

    test "succeeds when realm exists and device_registration_limit is removed", %{
      realm_name: realm_name
    } do
      update_values = %UpdateRealm{
        device_registration_limit: :remove_limit
      }

      assert {:ok,
              %{
                realm_name: ^realm_name,
                device_registration_limit: nil
              }} = Engine.update_realm(realm_name, update_values)
    end

    test "succeeds when realm exists and device_registration_limit is not set", %{
      realm_name: realm_name
    } do
      update_values = %UpdateRealm{
        device_registration_limit: nil
      }

      assert {:ok,
              %{
                realm_name: ^realm_name,
                device_registration_limit: 1
              }} = Engine.update_realm(realm_name, update_values)
    end

    test "succeeds when realm exists and datastream_maximum_storage_retention is updated", %{
      realm_name: realm_name
    } do
      new_retention = 100

      update_values = %UpdateRealm{
        datastream_maximum_storage_retention: new_retention
      }

      assert {:ok,
              %{
                realm_name: ^realm_name,
                datastream_maximum_storage_retention: ^new_retention
              }} = Engine.update_realm(realm_name, update_values)
    end

    test "succeeds when realm exists and datastream_maximum_storage_retention is removed", %{
      realm_name: realm_name
    } do
      update_values = %UpdateRealm{
        datastream_maximum_storage_retention: 0
      }

      assert {:ok,
              %{
                realm_name: ^realm_name,
                datastream_maximum_storage_retention: nil
              }} = Engine.update_realm(realm_name, update_values)
    end

    test "succeeds when realm exists and datastream_maximum_storage_retention is not set", %{
      realm_name: realm_name
    } do
      update_values = %UpdateRealm{
        datastream_maximum_storage_retention: nil
      }

      assert {:ok,
              %{
                realm_name: ^realm_name,
                datastream_maximum_storage_retention: 1
              }} = Engine.update_realm(realm_name, update_values)
    end

    test "fails when realm does not exist" do
      realm = "idontexist"

      update_values = %UpdateRealm{
        realm: realm,
        jwt_public_key_pem: "dontcare"
      }

      assert {:error, :realm_not_found} = Engine.update_realm(realm, update_values)
    end

    test "fails when update values are invalid", %{
      realm_name: realm_name
    } do
      update_values = %UpdateRealm{
        realm: realm_name,
        replication_factor: 10
      }

      assert {:error, :invalid_update_parameters} = Engine.update_realm(realm_name, update_values)
    end

    test "fails in case of db error", %{
      realm_name: realm_name
    } do
      new_public_key = "new_public_key"

      Astarte.Housekeeping.Queries
      |> stub(:update_public_key, fn _, _ -> {:error, %Xandra.ConnectionError{}} end)

      update_values = %UpdateRealm{
        realm: realm_name,
        jwt_public_key_pem: new_public_key
      }

      assert {:error, :update_public_key_fail} = Engine.update_realm(realm_name, update_values)
    end

    test "fails due to db error when realm exists and device_registration_limit cannot be removed",
         %{
           realm_name: realm_name
         } do
      Astarte.Housekeeping.Queries
      |> stub(:delete_device_registration_limit, fn _ -> {:error, %Xandra.ConnectionError{}} end)

      update_values = %UpdateRealm{
        device_registration_limit: :remove_limit
      }

      assert {:error, :delete_device_registration_limit_fail} =
               Engine.update_realm(realm_name, update_values)
    end

    test "fails due to db error when realm exists and datastream_maximum_storage_retention cannot be removed",
         %{
           realm_name: realm_name
         } do
      Astarte.Housekeeping.Queries
      |> stub(:delete_datastream_maximum_storage_retention, fn _ ->
        {:error, %Xandra.ConnectionError{}}
      end)

      update_values = %UpdateRealm{
        datastream_maximum_storage_retention: 0
      }

      assert {:error, :delete_datastream_maximum_storage_retention_fail} =
               Engine.update_realm(realm_name, update_values)
    end

    test "fails  due to db error when realm exists and device_registration_limit cannot be updated",
         %{
           realm_name: realm_name
         } do
      new_limit = 100

      Astarte.Housekeeping.Queries
      |> stub(:set_device_registration_limit, fn _, _ ->
        {:error, %Xandra.ConnectionError{}}
      end)

      update_values = %UpdateRealm{
        device_registration_limit: new_limit
      }

      assert {:error, :set_device_registration_limit_fail} =
               Engine.update_realm(realm_name, update_values)
    end

    test "fails due to db error when realm exists and datastream_maximum_storage_retention cannot be updated",
         %{
           realm_name: realm_name
         } do
      new_retention = 100

      Astarte.Housekeeping.Queries
      |> stub(:set_datastream_maximum_storage_retention, fn _, _ ->
        {:error, %Xandra.ConnectionError{}}
      end)

      update_values = %UpdateRealm{
        datastream_maximum_storage_retention: new_retention
      }

      assert {:error, :set_datastream_maximum_storage_retention_fail} =
               Engine.update_realm(realm_name, update_values)
    end
  end
end
