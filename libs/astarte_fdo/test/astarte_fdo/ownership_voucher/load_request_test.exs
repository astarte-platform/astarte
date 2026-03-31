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

defmodule Astarte.FDO.OwnershipVoucher.LoadRequestTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.FDO.Core.OwnershipVoucher, as: CoreOwnershipVoucher
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.Secrets
  alias Astarte.Secrets.Key

  import Astarte.FDO.Helpers

  # The public key PEM that matches the last entry of @sample_voucher.
  # Extracted via OVCore.entry_private_key/1 on the sample voucher.
  @sample_owner_public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAES+TkA7VtJQv9YQ75yl5btXKR/cso
  yfLzYWUTgxViGMfJkvql4W3zrtRaVPU9I06TOHFC2Mwy+9S3A7UWv/EWtg==
  -----END PUBLIC KEY-----
  """

  @sample_key_name "owner_key"
  @sample_realm "test_realm"

  @sample_params %{
    "ownership_voucher" => sample_voucher(),
    "key_name" => @sample_key_name,
    "realm_name" => @sample_realm
  }

  # A Secrets.Key struct whose public_pem matches the voucher's last entry.
  @sample_secrets_key %Key{
    name: @sample_key_name,
    namespace: "fdo_owner_keys/test_realm/ecdsa-p256",
    alg: :es256,
    public_pem: @sample_owner_public_key_pem
  }

  setup :verify_on_exit!

  describe "changeset/2 with valid params" do
    setup do
      stub(Secrets, :create_namespace, fn _realm, _alg ->
        {:ok, "fdo_owner_keys/test_realm/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, @sample_secrets_key} end)
      :ok
    end

    test "populates `device_guid` from the voucher header" do
      expected_guid = sample_device_guid()
      assert %LoadRequest{device_guid: ^expected_guid} = from_changeset!(@sample_params)
    end

    test "populates `cbor_ownership_voucher` as the base64-decoded voucher" do
      expected_cbor =
        sample_voucher()
        |> String.replace("-----BEGIN OWNERSHIP VOUCHER-----", "")
        |> String.replace("-----END OWNERSHIP VOUCHER-----", "")
        |> String.replace(~r/\s/, "")
        |> Base.decode64!()

      assert %LoadRequest{cbor_ownership_voucher: ^expected_cbor} =
               from_changeset!(@sample_params)
    end

    test "populates `owner_key_algorithm` as `:es256` for a secp256r1 voucher" do
      assert %LoadRequest{owner_key_algorithm: :es256} = from_changeset!(@sample_params)
    end

    test "populates `extracted_owner_key` with the key returned by Secrets" do
      assert %LoadRequest{extracted_owner_key: key} = from_changeset!(@sample_params)
      assert key == @sample_secrets_key
    end

    test "calls Secrets.create_namespace with the realm and :es256 algorithm" do
      expect(Secrets, :create_namespace, fn realm, alg ->
        assert realm == @sample_realm
        assert alg == :es256
        {:ok, "fdo_owner_keys/test_realm/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, @sample_secrets_key} end)

      from_changeset!(@sample_params)
    end

    test "calls Secrets.get_key with the provided key_name" do
      stub(Secrets, :create_namespace, fn _realm, _alg ->
        {:ok, "fdo_owner_keys/test_realm/ecdsa-p256"}
      end)

      expect(Secrets, :get_key, fn name, _opts ->
        assert name == @sample_key_name
        {:ok, @sample_secrets_key}
      end)

      from_changeset!(@sample_params)
    end
  end

  describe "changeset/2 rejects" do
    test "a missing `ownership_voucher`" do
      params = Map.delete(@sample_params, "ownership_voucher")
      assert {:error, changeset} = from_changeset(params)
      assert %{ownership_voucher: [_ | _]} = errors_on(changeset)
    end

    test "a missing `key_name`" do
      params = Map.delete(@sample_params, "key_name")
      assert {:error, changeset} = from_changeset(params)
      assert %{key_name: [_ | _]} = errors_on(changeset)
    end

    test "a missing `realm_name`" do
      params = Map.delete(@sample_params, "realm_name")
      assert {:error, changeset} = from_changeset(params)
      assert %{realm_name: [_ | _]} = errors_on(changeset)
    end

    test "an invalid (non-base64) ownership voucher" do
      params =
        Map.put(@sample_params, "ownership_voucher", """
        -----BEGIN OWNERSHIP VOUCHER-----
        * not valid base64 *
        -----END OWNERSHIP VOUCHER-----
        """)

      assert {:error, changeset} = from_changeset(params)
      assert %{ownership_voucher: [_ | _]} = errors_on(changeset)
    end

    test "a voucher whose key_name does not exist in the secrets store" do
      stub(Secrets, :create_namespace, fn _realm, _alg ->
        {:ok, "fdo_owner_keys/test_realm/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> :error end)

      assert {:error, changeset} = from_changeset(@sample_params)
      assert %{key_name: ["does not exist in secrets store"]} = errors_on(changeset)
    end

    test "a key_name whose public key does not match the voucher's last entry" do
      wrong_key = %Key{
        name: @sample_key_name,
        namespace: "fdo_owner_keys/test_realm/ecdsa-p256",
        alg: :es256,
        # A valid PEM but for a completely different EC key
        public_pem: """
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEocPEIHIrn08VRO5zkkDztwp72Sw0
        BSm0mZeLgOKkHLUPdVFFlc0EO82b1/S2Cwzwh8MIDDx0CN2b+IBl5bRwOw==
        -----END PUBLIC KEY-----
        """
      }

      stub(Secrets, :create_namespace, fn _realm, _alg ->
        {:ok, "fdo_owner_keys/test_realm/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, wrong_key} end)

      assert {:error, changeset} = from_changeset(@sample_params)

      assert %{key_name: ["does not match the public key in the ownership voucher's last entry"]} =
               errors_on(changeset)
    end
  end

  defp from_changeset(params) do
    %LoadRequest{}
    |> LoadRequest.changeset(params)
    |> Ecto.Changeset.apply_action(:insert)
  end

  defp from_changeset!(params) do
    %LoadRequest{}
    |> LoadRequest.changeset(params)
    |> Ecto.Changeset.apply_action!(:insert)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  describe "CoreOwnershipVoucher.key_algorithm_from_voucher/1" do
    test "returns {:ok, :es256} for the sample secp256r1 voucher" do
      assert {:ok, :es256} = CoreOwnershipVoucher.key_algorithm_from_voucher(sample_voucher())
    end

    test "returns {:error, _} for an invalid PEM string" do
      assert {:error, _} = CoreOwnershipVoucher.key_algorithm_from_voucher("not a voucher")
    end

    test "returns {:error, _} for a malformed base64 body" do
      bad_voucher = """
      -----BEGIN OWNERSHIP VOUCHER-----
      * not valid base64 *
      -----END OWNERSHIP VOUCHER-----
      """

      assert {:error, _} = CoreOwnershipVoucher.key_algorithm_from_voucher(bad_voucher)
    end
  end
end
