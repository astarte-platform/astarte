#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.HousekeepingWeb.GraphQL.Resolvers.RealmResolverTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Realms
  alias Astarte.Housekeeping.Realms.Realm
  alias Astarte.HousekeepingWeb.GraphQL.Resolvers.RealmResolver

  setup do
    resolution = %{
      context: %{}
    }

    %{resolution: resolution}
  end

  describe "list_realms/3" do
    test "returns a list of realms successfully", %{resolution: resolution} do
      realms = ["realm1", "realm2"]
      Mimic.expect(Realms, :list_realms, fn -> {:ok, realms} end)

      assert {:ok, ^realms} = RealmResolver.list_realms(nil, %{}, resolution)
    end

    test "returns an error when the list fails", %{resolution: resolution} do
      Mimic.expect(Realms, :list_realms, fn -> {:error, "Database error"} end)

      assert {:error, "Database error"} = RealmResolver.list_realms(nil, %{}, resolution)
    end
  end

  describe "get_realm/3" do
    test "returns a realm successfully", %{resolution: resolution} do
      realm_name = "testrealm"
      expected_realm = %Realm{realm_name: realm_name, jwt_public_key_pem: "key"}
      Mimic.expect(Realms, :get_realm, fn ^realm_name -> {:ok, expected_realm} end)

      args = %{realm_name: realm_name}
      assert {:ok, ^expected_realm} = RealmResolver.get_realm(nil, args, resolution)
    end

    test "returns formatted realm_not_found error", %{resolution: resolution} do
      realm_name = "testrealm"
      Mimic.expect(Realms, :get_realm, fn ^realm_name -> {:error, :realm_not_found} end)

      args = %{realm_name: realm_name}
      assert {:error, "Realm not found"} = RealmResolver.get_realm(nil, args, resolution)
    end
  end

  describe "create_realm/3" do
    test "creates a realm and passes async flag", %{resolution: resolution} do
      realm_data = %{realm_name: "newrealm", jwt_public_key_pem: "key"}
      expected_realm = %Realm{realm_name: "newrealm"}

      Mimic.expect(Realms, :create_realm, fn ^realm_data, [async_operation: true] ->
        {:ok, expected_realm}
      end)

      args = %{data: realm_data, async_operation: true}
      assert {:ok, ^expected_realm} = RealmResolver.create_realm(nil, args, resolution)
    end

    test "creates a realm and passes async flag synchronously", %{resolution: resolution} do
      realm_data = %{realm_name: "newrealm", jwt_public_key_pem: "key"}
      expected_realm = %Realm{realm_name: "newrealm"}

      Mimic.expect(Realms, :create_realm, fn ^realm_data, [async_operation: false] ->
        {:ok, expected_realm}
      end)

      args = %{data: realm_data, async_operation: false}
      assert {:ok, ^expected_realm} = RealmResolver.create_realm(nil, args, resolution)
    end

    test "returns formatted realm_already_exists error", %{resolution: resolution} do
      realm_data = %{realm_name: "newrealm", jwt_public_key_pem: "key"}

      Mimic.expect(Realms, :create_realm, fn _, _ -> {:error, :realm_already_exists} end)

      args = %{data: realm_data}
      assert {:error, "Realm already exists"} = RealmResolver.create_realm(nil, args, resolution)
    end
  end

  describe "update_realm/3" do
    test "normalizes limits and updates realm correctly", %{resolution: resolution} do
      realm_name = "updaterealm"

      # Testing normalization: passing nil converts to :unset
      args_data = %{
        "datastream_maximum_storage_retention" => nil,
        jwt_public_key_pem: "newkey",
        device_registration_limit: nil
      }

      expected_realm = %Realm{realm_name: realm_name}

      Mimic.expect(Realms, :update_realm, fn ^realm_name, params ->
        assert params.jwt_public_key_pem == "newkey"
        assert params.device_registration_limit == :unset
        assert params["datastream_maximum_storage_retention"] == :unset
        {:ok, expected_realm}
      end)

      args = %{realm_name: realm_name, data: args_data}
      assert {:ok, ^expected_realm} = RealmResolver.update_realm(nil, args, resolution)
    end

    test "preserves valid integers during normalization", %{resolution: resolution} do
      realm_name = "updaterealm"

      args_data = %{
        device_registration_limit: 10,
        datastream_maximum_storage_retention: 20
      }

      expected_realm = %Realm{realm_name: realm_name}

      Mimic.expect(Realms, :update_realm, fn ^realm_name, params ->
        assert params.device_registration_limit == 10
        assert params.datastream_maximum_storage_retention == 20
        {:ok, expected_realm}
      end)

      args = %{realm_name: realm_name, data: args_data}
      assert {:ok, ^expected_realm} = RealmResolver.update_realm(nil, args, resolution)
    end
  end

  describe "delete_realm/3" do
    test "deletes a realm applying the async flag", %{resolution: resolution} do
      realm_name = "deadrealm"

      Mimic.expect(Realms, :delete_realm, fn ^realm_name, [async_operation: true] -> :ok end)

      args = %{realm_name: realm_name, async_operation: true}

      assert {:ok, "Realm deleted successfully"} =
               RealmResolver.delete_realm(nil, args, resolution)
    end

    test "formats proper errors upon failure", %{resolution: resolution} do
      realm_name = "deadrealm"

      Mimic.expect(Realms, :delete_realm, fn _, _ -> {:error, :connected_devices_present} end)

      args = %{realm_name: realm_name}

      assert {:error, "Connected devices present"} =
               RealmResolver.delete_realm(nil, args, resolution)
    end
  end

  describe "get_default_replication/3" do
    test "returns simple strategy configuration", %{resolution: resolution} do
      Mimic.expect(Config, :astarte_keyspace_replication_strategy!, fn -> :simple_strategy end)
      Mimic.expect(Config, :astarte_keyspace_replication_factor!, fn -> 3 end)

      assert {:ok, result} = RealmResolver.get_default_replication(nil, %{}, resolution)
      assert result.replication_class == "simple_strategy"
      assert result.replication_factor == 3
    end

    test "returns network topology strategy configuration", %{resolution: resolution} do
      Mimic.expect(Config, :astarte_keyspace_replication_strategy!, fn ->
        :network_topology_strategy
      end)

      Mimic.expect(Config, :astarte_keyspace_network_replication_map!, fn ->
        %{"datacenter1" => 3}
      end)

      assert {:ok, result} = RealmResolver.get_default_replication(nil, %{}, resolution)
      assert result.replication_class == "network_topology_strategy"
      assert result.datacenter_replication_factor == %{"datacenter1" => 3}
    end

    test "handles unknown strategies gracefully by defaulting to network_topology without a map",
         %{resolution: resolution} do
      Mimic.expect(Config, :astarte_keyspace_replication_strategy!, fn -> :unknown_strategy end)

      assert {:ok, result} = RealmResolver.get_default_replication(nil, %{}, resolution)
      assert result.replication_class == "network_topology_strategy"
      assert result.datacenter_replication_factor == %{}
    end
  end
end
