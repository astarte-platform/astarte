#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.Housekeeping.QueriesTest do
  use ExUnit.Case
  doctest Astarte.Housekeeping.Queries

  alias Astarte.Housekeeping.DatabaseTestHelper
  alias Astarte.Housekeeping.Queries

  @realm1 "test1"
  @realm2 "test2"

  setup_all do
    DatabaseTestHelper.wait_and_initialize()

    on_exit(fn ->
      DatabaseTestHelper.drop_astarte_keyspace()
    end)
  end

  setup [:realm_cleanup]

  test "realm creation" do
    assert Queries.create_realm(@realm1, "test1publickey", 1, 1, []) == :ok
    assert Queries.create_realm(@realm2, "test2publickey", 1, 0, []) == :ok

    assert %{
             realm_name: @realm1,
             jwt_public_key_pem: "test1publickey",
             replication_class: "SimpleStrategy",
             replication_factor: 1,
             device_registration_limit: 1
           } = Queries.get_realm(@realm1)

    assert %{
             realm_name: @realm2,
             jwt_public_key_pem: "test2publickey",
             replication_class: "SimpleStrategy",
             replication_factor: 1,
             device_registration_limit: nil
           } = Queries.get_realm(@realm2)
  end

  test "update realm public key" do
    Queries.create_realm(@realm1, "test1publickey", 1, 1, []) == :ok

    new_public_key = "new_public_key"

    assert {:ok, %Xandra.Void{}} = Queries.update_public_key(@realm1, new_public_key)

    assert [
             %{
               "value" => ^new_public_key
             }
           ] =
             Xandra.Cluster.execute!(
               :xandra,
               "SELECT value FROM #{@realm1}.kv_store WHERE group='auth' AND key='jwt_public_key_pem'"
             )
             |> Enum.to_list()
  end

  test "set device registration limit" do
    Queries.create_realm(@realm1, "test1publickey", 1, 1, []) == :ok

    new_limit = 100

    assert {:ok, %Xandra.Void{}} = Queries.set_device_registration_limit(@realm1, new_limit)

    assert [
             %{
               "device_registration_limit" => ^new_limit
             }
           ] =
             Xandra.Cluster.execute!(
               :xandra,
               "SELECT device_registration_limit FROM astarte.realms WHERE realm_name = :realm_name",
               %{"realm_name" => {"varchar", @realm1}}
             )
             |> Enum.to_list()
  end

  test "remove device registration limit" do
    Queries.create_realm(@realm1, "test1publickey", 1, 1, []) == :ok

    assert {:ok, %Xandra.Void{}} = Queries.delete_device_registration_limit(@realm1)

    assert [
             %{
               "device_registration_limit" => nil
             }
           ] =
             Xandra.Cluster.execute!(
               :xandra,
               "SELECT device_registration_limit FROM astarte.realms WHERE realm_name = :realm_name",
               %{"realm_name" => {"varchar", @realm1}}
             )
             |> Enum.to_list()
  end

  defp realm_cleanup(_context) do
    on_exit(fn ->
      DatabaseTestHelper.realm_cleanup(@realm1)
      DatabaseTestHelper.realm_cleanup(@realm2)
    end)

    :ok
  end
end
