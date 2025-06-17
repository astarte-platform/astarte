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

defmodule Astarte.Housekeeping.API.Realms.QueriesTest do
  use Astarte.Housekeeping.API.DataCase, async: true
  use Mimic

  alias Astarte.Housekeeping.API.Helpers.Database
  alias Astarte.Housekeeping.API.Realms.Queries

  setup %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} do
    on_exit(fn ->
      Database.setup_database_access(astarte_instance_id)
      Queries.set_datastream_maximum_storage_retention(realm_name, 50)
      Queries.set_device_registration_limit(realm_name, 500)
      Database.insert_public_key(realm_name)
    end)

    :ok
  end

  describe "is_realm_existing/1" do
    test "returns {:ok, true} when the realm exists", %{realm_name: realm_name} do
      assert {:ok, true} = Queries.is_realm_existing(realm_name)
    end

    test "returns {:ok, false} when the realm does not exist" do
      assert {:ok, false} = Queries.is_realm_existing("nonexisting")
    end

    test "returns {:error, _} when there is a database connection error", %{
      realm_name: realm_name
    } do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, _} = Queries.is_realm_existing(realm_name)
    end
  end

  describe "set device registration limit" do
    test "set limit returns ok ", %{realm_name: realm_name} do
      assert :ok = Queries.set_device_registration_limit(realm_name, 10)

      assert {:ok, %{device_registration_limit: 10, realm_name: ^realm_name}} =
               Queries.get_realm(realm_name)
    end

    test "set limit fails due to db error", %{realm_name: realm_name} do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)
      assert_raise Xandra.Error, fn -> Queries.set_device_registration_limit(realm_name, 10) end
    end

    test "set limit fails due to db connection error", %{realm_name: realm_name} do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.set_device_registration_limit(realm_name, 10)
      end
    end
  end

  describe "delete device registration limit" do
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
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)
      assert_raise Xandra.Error, fn -> Queries.delete_device_registration_limit(realm_name) end
    end

    test "fails due to db connection error", %{realm_name: realm_name} do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.delete_device_registration_limit(realm_name)
      end
    end
  end

  describe "set storage retention" do
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
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)

      assert_raise Xandra.Error, fn ->
        Queries.set_datastream_maximum_storage_retention(realm_name, 10)
      end
    end

    test "fails due to db connection error", %{realm_name: realm_name} do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.set_datastream_maximum_storage_retention(realm_name, 10)
      end
    end
  end

  describe "delete storage retention" do
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
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)

      assert_raise Xandra.Error, fn ->
        Queries.delete_datastream_maximum_storage_retention(realm_name)
      end
    end

    test "fails due to db connection error", %{realm_name: realm_name} do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.delete_datastream_maximum_storage_retention(realm_name)
      end
    end
  end

  describe "update public key" do
    test "returns ok ", %{realm_name: realm_name} do
      assert :ok = Queries.update_public_key(realm_name, "newPublicKey")

      assert {:ok,
              %{
                jwt_public_key_pem: "newPublicKey",
                realm_name: ^realm_name
              }} = Queries.get_realm(realm_name)
    end

    test "fails due to db error", %{realm_name: realm_name} do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)

      assert_raise Xandra.Error, fn ->
        Queries.update_public_key(realm_name, "newPublicKey")
      end
    end

    test "fails due to db connection error", %{realm_name: realm_name} do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert_raise Xandra.ConnectionError, fn ->
        Queries.update_public_key(realm_name, "newPublicKey")
      end
    end
  end
end
