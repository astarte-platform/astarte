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

  alias Astarte.Housekeeping.DatabaseTestHelper
  alias Astarte.Housekeeping.Engine
  alias Astarte.Housekeeping.Queries
  alias Astarte.RPC.Protocol.Housekeeping.UpdateRealm

  @realm1 "test1"

  setup_all do
    DatabaseTestHelper.wait_and_initialize()

    on_exit(fn ->
      DatabaseTestHelper.drop_astarte_keyspace()
    end)
  end

  setup do
    on_exit(fn ->
      DatabaseTestHelper.realm_cleanup(@realm1)
    end)

    :ok
  end

  describe "Realm update" do
    test "succeeds when realm exists and valid update values are given" do
      :ok = Queries.create_realm(@realm1, "test1publickey", 1, 1, [])

      new_public_key = "new_public_key"

      update_values = %UpdateRealm{
        realm: @realm1,
        jwt_public_key_pem: new_public_key
      }

      assert {:ok,
              %{
                realm_name: @realm1,
                jwt_public_key_pem: ^new_public_key,
                device_registration_limit: 1
              }} = Engine.update_realm(@realm1, update_values)
    end

    test "succeeds when realm exists and empty update values are given" do
      :ok = Queries.create_realm(@realm1, "test1publickey", 1, 1, [])

      update_values = %UpdateRealm{
        realm: @realm1
      }

      assert {:ok,
              %{
                realm_name: @realm1,
                jwt_public_key_pem: "test1publickey",
                device_registration_limit: 1
              }} = Engine.update_realm(@realm1, update_values)
    end

    test "succeeds when realm exists and device_registration_limit is updated" do
      :ok = Queries.create_realm(@realm1, "test1publickey", 1, 1, [])

      new_limit = 100

      update_values = %UpdateRealm{
        device_registration_limit: new_limit
      }

      assert {:ok,
              %{
                realm_name: @realm1,
                device_registration_limit: ^new_limit
              }} = Engine.update_realm(@realm1, update_values)
    end

    test "succeeds when realm exists and device_registration_limit is removed" do
      :ok = Queries.create_realm(@realm1, "test1publickey", 1, 1, [])

      update_values = %UpdateRealm{
        device_registration_limit: :remove_limit
      }

      assert {:ok,
              %{
                realm_name: @realm1,
                device_registration_limit: nil
              }} = Engine.update_realm(@realm1, update_values)
    end

    test "succeeds when realm exists and device_registration_limit is not set" do
      :ok = Queries.create_realm(@realm1, "test1publickey", 1, 1, [])

      update_values = %UpdateRealm{
        device_registration_limit: nil
      }

      assert {:ok,
              %{
                realm_name: @realm1,
                device_registration_limit: 1
              }} = Engine.update_realm(@realm1, update_values)
    end

    test "fails when realm does not exist" do
      realm = "i_dont_exist"

      update_values = %UpdateRealm{
        realm: realm,
        jwt_public_key_pem: "dontcare"
      }

      assert {:error, :realm_not_found} = Engine.update_realm(realm, update_values)
    end

    test "fails when update values are invalid" do
      :ok = Queries.create_realm(@realm1, "test1publickey", 1, 1, [])

      update_values = %UpdateRealm{
        realm: @realm1,
        replication_factor: 10
      }

      assert {:error, :invalid_update_parameters} = Engine.update_realm(@realm1, update_values)
    end
  end
end
