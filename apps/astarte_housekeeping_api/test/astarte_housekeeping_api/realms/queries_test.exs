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
  alias Astarte.Housekeeping.API.Realms

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
            {:invalid_replication, "replication_factor 9 is >= 1 nodes in datacenter datacenter1"}} =
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
