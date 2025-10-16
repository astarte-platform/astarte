#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.AgentTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device

  import Mox
  import Astarte.Helpers.Triggers

  alias Astarte.Helpers.Database
  alias Astarte.Pairing.Agent

  describe "register_device" do
    alias Astarte.Pairing.Agent.DeviceRegistrationResponse

    @test_hw_id "PDL3KNj7RVifHZD-1w_6wA"

    @valid_attrs %{"hw_id" => @test_hw_id}
    @no_hw_id_attrs %{}
    @invalid_hw_id_attrs %{"hw_id" => "invalid"}

    test "successful call", %{realm_name: realm_name} do
      assert {:ok, %DeviceRegistrationResponse{credentials_secret: credentials_secret}} =
               Agent.register_device(realm_name, @valid_attrs)

      assert is_binary(credentials_secret)
    end

    test "successful trigger emission on successful call", %{
      realm_name: realm_name
    } do
      ref =
        register_device_registration_trigger(realm_name, device_id: @test_hw_id)

      reset_cache(realm_name)

      assert {:ok, %DeviceRegistrationResponse{credentials_secret: credentials_secret}} =
               Agent.register_device(realm_name, @valid_attrs)

      assert_receive ^ref
    end

    test "succesful call with initial_introspection", %{realm_name: realm_name} do
      initial_introspection = %{
        "org.astarteplatform.Values" => %{"major" => 0, "minor" => 4},
        "org.astarteplatform.OtherValues" => %{"major" => 1, "minor" => 0}
      }

      attrs = Map.put(@valid_attrs, "initial_introspection", initial_introspection)

      assert {:ok, %DeviceRegistrationResponse{credentials_secret: credentials_secret}} =
               Agent.register_device(realm_name, attrs)

      assert is_binary(credentials_secret)
    end

    test "succesful trigger emission on successful call with initial_introspection", %{
      realm_name: realm_name
    } do
      ref =
        register_device_registration_trigger(realm_name, device_id: @test_hw_id)

      reset_cache(realm_name)

      initial_introspection = %{
        "org.astarteplatform.Values" => %{"major" => 0, "minor" => 4},
        "org.astarteplatform.OtherValues" => %{"major" => 1, "minor" => 0}
      }

      attrs = Map.put(@valid_attrs, "initial_introspection", initial_introspection)

      assert {:ok, %DeviceRegistrationResponse{credentials_secret: credentials_secret}} =
               Agent.register_device(realm_name, attrs)

      assert_receive ^ref
    end

    test "returns error changeset with missing hardware ID", %{realm_name: realm_name} do
      assert {:error, changeset} = Agent.register_device(realm_name, @no_hw_id_attrs)

      assert is_struct(changeset, Ecto.Changeset)
      assert changeset.valid? == false

      assert changeset.errors[:hw_id] ==
               {"can't be blank", [{:validation, :required}]}
    end

    test "returns error changeset with invalid hardware ID", %{realm_name: realm_name} do
      assert {:error, changeset} =
               Agent.register_device(realm_name, @invalid_hw_id_attrs)

      assert is_struct(changeset, Ecto.Changeset)
      assert changeset.valid? == false

      assert changeset.errors[:hw_id] ==
               {"is not a valid base64 encoded 128 bits id", []}
    end

    test "returns error changeset for negative major version in introspection", %{
      realm_name: realm_name
    } do
      initial_introspection = %{
        "org.astarteplatform.Values" => %{"major" => -1, "minor" => 0}
      }

      attrs = Map.put(@valid_attrs, "initial_introspection", initial_introspection)
      assert {:error, changeset} = Agent.register_device(realm_name, attrs)

      assert is_struct(changeset, Ecto.Changeset)
      assert changeset.valid? == false

      assert changeset.errors[:initial_introspection] ==
               {"has negative versions in interface org.astarteplatform.Values", []}
    end

    test "returns error changeset for negative minor version in introspection", %{
      realm_name: realm_name
    } do
      initial_introspection = %{
        "org.astarteplatform.OtherValues" => %{"major" => 1, "minor" => -2}
      }

      attrs = Map.put(@valid_attrs, "initial_introspection", initial_introspection)
      assert {:error, changeset} = Agent.register_device(realm_name, attrs)

      assert is_struct(changeset, Ecto.Changeset)
      assert changeset.valid? == false

      assert changeset.errors[:initial_introspection] ==
               {"has negative versions in interface org.astarteplatform.OtherValues", []}
    end

    test "registers an existing unconfirmed device", %{
      realm_name: realm_name,
      device: device
    } do
      {:ok, _} = Database.update_device(device.id, realm_name, first_credentials_request: nil)

      assert {:ok, %DeviceRegistrationResponse{credentials_secret: credentials_secret}} =
               Agent.register_device(realm_name, %{"hw_id" => device.encoded_id})

      assert is_binary(credentials_secret)
    end

    test "successfully emit trigger when registering an existing unconfirmed device", %{
      realm_name: realm_name,
      device: device
    } do
      ref =
        register_device_registration_trigger(realm_name, device_id: device.encoded_id)

      reset_cache(realm_name)
      {:ok, _} = Database.update_device(device.id, realm_name, first_credentials_request: nil)

      assert {:ok, %DeviceRegistrationResponse{credentials_secret: credentials_secret}} =
               Agent.register_device(realm_name, %{"hw_id" => device.encoded_id})

      assert_receive ^ref
    end

    test "fails for an existing confirmed device", %{
      realm_name: realm_name,
      device: device
    } do
      {:ok, _} =
        Database.update_device(device.id, realm_name,
          first_credentials_request: DateTime.utc_now()
        )

      assert {:error, :device_already_registered} =
               Agent.register_device(realm_name, %{"hw_id" => device.encoded_id})
    end
  end

  describe "unregister device" do
    setup [:verify_on_exit!]

    test "successful call", %{realm_name: realm_name, device: device} do
      assert :ok = Agent.unregister_device(realm_name, device.encoded_id)
    end

    test "unregistered device", %{realm_name: realm_name} do
      device_id = Astarte.Core.Device.random_device_id() |> Astarte.Core.Device.encode_device_id()
      assert {:error, :device_not_found} = Agent.unregister_device(realm_name, device_id)
    end

    test "realm not found", %{device: device} do
      assert_raise Xandra.Error, ~r"Keyspace .*nonexistingrealm does not exist", fn ->
        Agent.unregister_device("nonexistingrealm", device.encoded_id)
      end
    end

    test "invalid device id", %{realm_name: realm_name} do
      assert {:error, :invalid_device_id} = Agent.unregister_device(realm_name, "invalid")
    end
  end
end
