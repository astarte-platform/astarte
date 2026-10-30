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

defmodule Astarte.PairingWeb.GraphQL.Resolvers.FdoResolverTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO
  alias Astarte.PairingWeb.GraphQL.Resolvers.FdoResolver
  alias Astarte.Secrets
  alias Astarte.Secrets.Key

  @context %{context: %{realm_name: "testrealm"}}

  # Owner keys live in OpenBao only, namespaced by realm, so each test gets a
  # realm of its own and the module can stay async.
  defp owner_keys(_context) do
    realm = "fdoresolver#{System.unique_integer([:positive])}"
    {:ok, es256} = Secrets.create_fdo_namespace(realm, :es256)
    {:ok, es384} = Secrets.create_fdo_namespace(realm, :es384)

    {:ok, _} = Secrets.create_keypair("owner_key_a", :es256, namespace: es256)
    {:ok, _} = Secrets.create_keypair("owner_key_b", :es256, namespace: es256)
    {:ok, _} = Secrets.create_keypair("owner_key_c", :es384, namespace: es384)

    on_exit(fn -> Enum.each([es256, es384], &delete_keys/1) end)

    %{
      resolution: %{context: %{realm_name: realm}},
      realm: realm,
      namespace: es256,
      expected_owner_keys: %{
        es256: ["owner_key_a", "owner_key_b"],
        es384: ["owner_key_c"],
        rs256: [],
        rs384: []
      }
    }
  end

  defp delete_keys(namespace) do
    {:ok, key_names} = Secrets.list_keys_names(namespace: namespace)

    Enum.each(key_names, fn key_name ->
      Secrets.enable_key_deletion(key_name, namespace: namespace)
      Secrets.delete_key(key_name, namespace: namespace)
    end)
  end

  describe "list_owner_keys/3" do
    setup :owner_keys

    test "lists the realm's keys for every algorithm", context do
      assert FdoResolver.list_owner_keys(nil, %{}, context.resolution) ==
               {:ok, context.expected_owner_keys}
    end

    test "lists only the keys of the requested algorithm", context do
      assert FdoResolver.list_owner_keys(nil, %{key_algorithm: "ecdsa-p256"}, context.resolution) ==
               {:ok, Map.take(context.expected_owner_keys, [:es256])}
    end
  end

  describe "get_owner_key/3" do
    setup :owner_keys

    test "returns the key's public PEM", context do
      {:ok, %Key{public_pem: public_pem}} =
        Secrets.get_key("owner_key_a", namespace: context.namespace)

      args = %{key_algorithm: "ecdsa-p256", key_name: "owner_key_a"}

      assert FdoResolver.get_owner_key(nil, args, context.resolution) ==
               {:ok, %{key_name: "owner_key_a", public_key: public_pem}}
    end

    test "returns an error when the algorithm is invalid", context do
      args = %{key_algorithm: "bogus", key_name: "owner_key_a"}

      assert FdoResolver.get_owner_key(nil, args, context.resolution) ==
               {:error, "Invalid key algorithm"}
    end

    test "returns an error when the key doesn't exist", context do
      args = %{key_algorithm: "ecdsa-p256", key_name: "missing"}

      assert FdoResolver.get_owner_key(nil, args, context.resolution) == {:error, "Key not found"}
    end
  end

  describe "create_or_upload_owner_key/3" do
    setup :owner_keys

    test "creates the key and returns its public PEM", context do
      args = %{action: "create", key_name: "new_key", key_algorithm: "ecdsa-p256"}

      assert {:ok, public_pem} =
               FdoResolver.create_or_upload_owner_key(nil, args, context.resolution)

      assert {:ok, %Key{public_pem: ^public_pem}} =
               Secrets.get_key("new_key", namespace: context.namespace)
    end

    test "returns the validation error and creates nothing when options are invalid", context do
      # :key_name is required and missing.
      args = %{action: "create", key_algorithm: "ecdsa-p256"}

      assert {:error, "Validation failed: " <> _} =
               FdoResolver.create_or_upload_owner_key(nil, args, context.resolution)

      assert {:ok, ["owner_key_a", "owner_key_b"]} =
               Secrets.list_keys_names(namespace: context.namespace)
    end
  end

  describe "register_ownership_voucher/3" do
    @args %{
      ownership_voucher: "voucher-pem",
      key_name: "mykey",
      key_algorithm: "ecdsa-p256"
    }

    test "returns the public key and guid on success" do
      raw_guid = UUID.uuid4(:raw)

      expect(FDO.OwnershipVoucher, :register, fn _params, "testrealm" ->
        {:ok, %{public_key: "PEM", guid: raw_guid}}
      end)

      assert FdoResolver.register_ownership_voucher(nil, @args, @context) ==
               {:ok, %{public_key: "PEM", guid: UUID.binary_to_string!(raw_guid)}}
    end

    test "formats a changeset error" do
      changeset =
        %Astarte.FDO.OwnershipVoucher.LoadRequest{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:key_name, "does not exist in secrets store")

      expect(FDO.OwnershipVoucher, :register, fn _params, "testrealm" ->
        {:error, changeset}
      end)

      assert {:error, "Validation failed: " <> _} =
               FdoResolver.register_ownership_voucher(nil, @args, @context)
    end

    test "passes through a non-changeset error unchanged" do
      expect(FDO.OwnershipVoucher, :register, fn _params, "testrealm" ->
        {:error, :timeout}
      end)

      assert FdoResolver.register_ownership_voucher(nil, @args, @context) == {:error, :timeout}
    end
  end

  describe "delete_ownership_voucher/3" do
    @guid "2b0e0b8f-5c55-4ffb-8a4f-0c3a1e6d7f21"

    test "deletes the voucher by its binary GUID and returns the GUID it was given" do
      binary_guid = UUID.string_to_binary!(@guid)

      expect(OwnershipVoucher, :delete, fn "testrealm", ^binary_guid -> :ok end)

      assert FdoResolver.delete_ownership_voucher(nil, %{guid: @guid}, @context) == {:ok, @guid}
    end

    test "reports a GUID that isn't a UUID as not found, without deleting anything" do
      reject(&OwnershipVoucher.delete/2)

      assert FdoResolver.delete_ownership_voucher(nil, %{guid: "not-a-guid"}, @context) ==
               {:error, "Failed to delete voucher: :not_found"}
    end

    test "reports why the deletion failed" do
      expect(OwnershipVoucher, :delete, fn _realm, _guid -> {:error, :not_found} end)

      assert FdoResolver.delete_ownership_voucher(nil, %{guid: @guid}, @context) ==
               {:error, "Failed to delete voucher: :not_found"}
    end
  end
end
