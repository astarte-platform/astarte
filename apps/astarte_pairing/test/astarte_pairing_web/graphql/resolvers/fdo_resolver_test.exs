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
  use ExUnit.Case
  use Mimic

  alias Astarte.Pairing.FDOOperations
  alias Astarte.PairingWeb.GraphQL.Resolvers.FdoResolver
  alias Astarte.Secrets.Core
  alias Astarte.Secrets.Key
  alias Astarte.Secrets.OwnerKeyInitialization

  @context %{context: %{realm_name: "testrealm"}}

  describe "list_owner_keys/3 without a key_algorithm arg" do
    test "queries every asymmetric algorithm Secrets.Core knows about" do
      expected_algorithms = Core.asymmetric_key_algorithms()

      expect(Core, :get_keys, fn "testrealm", algorithms ->
        assert algorithms == expected_algorithms
        {:ok, %{}}
      end)

      assert FdoResolver.list_owner_keys(nil, %{}, @context) == {:ok, %{}}
    end
  end

  describe "get_owner_key/3" do
    test "returns the key when the algorithm is valid and the key exists" do
      expect(Core, :string_to_key_type, fn "ecdsa-p256" -> {:ok, :es256} end)

      expect(Core, :find_key, fn "testrealm", "mykey", :es256 ->
        {:ok, %Key{name: "mykey", public_pem: "PEM"}}
      end)

      args = %{key_algorithm: "ecdsa-p256", key_name: "mykey"}

      assert FdoResolver.get_owner_key(nil, args, @context) ==
               {:ok, %{key_name: "mykey", public_key: "PEM"}}
    end

    test "returns an error without calling find_key when the algorithm is invalid" do
      expect(Core, :string_to_key_type, fn "bogus" -> :error end)
      reject(&Core.find_key/3)

      args = %{key_algorithm: "bogus", key_name: "mykey"}

      assert FdoResolver.get_owner_key(nil, args, @context) == {:error, "Invalid key algorithm"}
    end

    test "returns an error when the key doesn't exist" do
      expect(Core, :string_to_key_type, fn "ecdsa-p256" -> {:ok, :es256} end)
      expect(Core, :find_key, fn "testrealm", "missing", :es256 -> :not_found end)

      args = %{key_algorithm: "ecdsa-p256", key_name: "missing"}

      assert FdoResolver.get_owner_key(nil, args, @context) == {:error, "Key not found"}
    end
  end

  describe "create_or_upload_owner_key/3" do
    test "returns the changeset error without calling create_or_upload when options are invalid" do
      reject(&OwnerKeyInitialization.create_or_upload/2)

      # :key_name is required and missing.
      args = %{action: "create", key_algorithm: "ecdsa-p256"}

      assert {:error, "Validation failed: " <> _} =
               FdoResolver.create_or_upload_owner_key(nil, args, @context)
    end

    test "returns the response when options are valid and creation succeeds" do
      expect(OwnerKeyInitialization, :create_or_upload, fn options, "testrealm" ->
        assert options.key_name == "mykey"
        {:ok, "created"}
      end)

      args = %{action: "create", key_name: "mykey", key_algorithm: "ecdsa-p256"}

      assert FdoResolver.create_or_upload_owner_key(nil, args, @context) == {:ok, "created"}
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

      expect(FDOOperations, :register_ownership_voucher, fn _params, "testrealm" ->
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

      expect(FDOOperations, :register_ownership_voucher, fn _params, "testrealm" ->
        {:error, changeset}
      end)

      assert {:error, "Validation failed: " <> _} =
               FdoResolver.register_ownership_voucher(nil, @args, @context)
    end

    test "passes through a non-changeset error unchanged" do
      expect(FDOOperations, :register_ownership_voucher, fn _params, "testrealm" ->
        {:error, :timeout}
      end)

      assert FdoResolver.register_ownership_voucher(nil, @args, @context) == {:error, :timeout}
    end
  end
end
