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
  alias Astarte.FDO.Core.OwnershipVoucher.Core, as: OVCore
  alias Astarte.FDO.Core.PublicKey
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.Secrets
  alias Astarte.Secrets.Key

  import Astarte.FDO.Helpers

  # The public key PEM that matches the last entry of @sample_voucher.
  # Extracted via OVCore.entry_public_key/1 on the sample voucher.
  @sample_owner_public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAES+TkA7VtJQv9YQ75yl5btXKR/cso
  yfLzYWUTgxViGMfJkvql4W3zrtRaVPU9I06TOHFC2Mwy+9S3A7UWv/EWtg==
  -----END PUBLIC KEY-----
  """

  @sample_key_name "owner_key"
  @sample_key_algorithm "ecdsa-p256"
  @sample_realm "test_realm"

  @sample_params %{
    "ownership_voucher" => sample_voucher(),
    "key_name" => @sample_key_name,
    "key_algorithm" => @sample_key_algorithm,
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

    test "a missing `key_algorithm`" do
      params = Map.delete(@sample_params, "key_algorithm")
      assert {:error, changeset} = from_changeset(params)
      assert %{key_algorithm: [_ | _]} = errors_on(changeset)
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

  defp sample_replacement_public_key_pem do
    @sample_owner_public_key_pem
  end

  defp sample_replacement_rendezvous_info_b64 do
    CBOR.encode([]) |> Base.encode64()
  end

  describe "changeset/2 with replacement fields" do
    setup do
      stub(Secrets, :create_namespace, fn _realm, _alg ->
        {:ok, "fdo_owner_keys/test_realm/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, @sample_secrets_key} end)
      :ok
    end

    test "accepts params without replacement fields" do
      assert %LoadRequest{} = from_changeset!(@sample_params)
    end

    test "accepts a valid `replacement_rendezvous_info`" do
      params =
        Map.put(
          @sample_params,
          "replacement_rendezvous_info",
          sample_replacement_rendezvous_info_b64()
        )

      assert %LoadRequest{} = from_changeset!(params)
    end

    test "accepts a valid `replacement_public_key`" do
      params =
        Map.put(@sample_params, "replacement_public_key", sample_replacement_public_key_pem())

      assert %LoadRequest{} = from_changeset!(params)
    end

    test "accepts a valid base64 `replacement_guid`" do
      guid = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      params = Map.put(@sample_params, "replacement_guid", Base.encode64(guid))

      assert %LoadRequest{} = from_changeset!(params)
    end

    test "rejects invalid base64 for `replacement_rendezvous_info`" do
      params = Map.put(@sample_params, "replacement_rendezvous_info", "not-valid-base64!!!")

      assert {:error, changeset} = from_changeset(params)
      assert %{replacement_rendezvous_info: [_ | _]} = errors_on(changeset)
    end

    test "rejects invalid CBOR for `replacement_rendezvous_info`" do
      params =
        Map.put(
          @sample_params,
          "replacement_rendezvous_info",
          Base.encode64(<<0xFF, 0xFE>>)
        )

      assert {:error, changeset} = from_changeset(params)
      assert %{replacement_rendezvous_info: [_ | _]} = errors_on(changeset)
    end

    test "rejects invalid PEM for `replacement_public_key`" do
      params = Map.put(@sample_params, "replacement_public_key", "not a valid PEM")

      assert {:error, changeset} = from_changeset(params)
      assert %{replacement_public_key: [_ | _]} = errors_on(changeset)
    end

    test "rejects invalid base64 for `replacement_guid`" do
      params = Map.put(@sample_params, "replacement_guid", "not-valid-base64!!!")

      assert {:error, changeset} = from_changeset(params)
      assert %{replacement_guid: [_ | _]} = errors_on(changeset)
    end
  end

  describe "changeset/2 with a secp384r1/x509 voucher" do
    test "parses successfully and sets owner_key_algorithm to :es384" do
      {voucher, private_pem} = generate_p384_x509_data_and_pem()
      voucher_pem = voucher_to_pem(voucher)
      public_pem = ec_private_pem_to_public_pem(private_pem)

      p384_key = %Key{
        name: @sample_key_name,
        namespace: "fdo_owner_keys/#{@sample_realm}/ecdsa-p384",
        alg: :es384,
        public_pem: public_pem
      }

      stub(Secrets, :create_namespace, fn _realm, :es384 ->
        {:ok, "fdo_owner_keys/#{@sample_realm}/ecdsa-p384"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, p384_key} end)

      params = Map.put(@sample_params, "ownership_voucher", voucher_pem)

      assert %LoadRequest{owner_key_algorithm: :es384} = from_changeset!(params)
    end
  end

  describe "changeset/2 with a secp256r1/x5chain voucher" do
    test "parses successfully and populates device_guid" do
      {voucher, private_pem} = generate_p256_x5chain_data_and_pem()
      voucher_pem = voucher_to_pem(voucher)
      public_pem = ec_private_pem_to_public_pem(private_pem)

      x5chain_key = %Key{
        name: @sample_key_name,
        namespace: "fdo_owner_keys/#{@sample_realm}/ecdsa-p256",
        alg: :es256,
        public_pem: public_pem
      }

      stub(Secrets, :create_namespace, fn _realm, :es256 ->
        {:ok, "fdo_owner_keys/#{@sample_realm}/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, x5chain_key} end)

      params = Map.put(@sample_params, "ownership_voucher", voucher_pem)

      result = from_changeset!(params)
      assert %LoadRequest{owner_key_algorithm: :es256, device_guid: guid} = result
      assert is_binary(guid) and byte_size(guid) == 16
    end
  end

  describe "changeset/2 public_keys_match? :x5chain path" do
    test "accepts a key whose EC point is embedded in the x5chain certificate" do
      # generate_p256_x509_data_and_pem returns a voucher whose cert_chain holds
      # a real self-signed DER cert for the device key.
      {voucher, private_pem} = generate_p256_x509_data_and_pem()
      [cert_der | _] = voucher.cert_chain
      public_pem = ec_private_pem_to_public_pem(private_pem)

      stub(OVCore, :entry_private_key, fn _entry ->
        {:ok, %PublicKey{encoding: :x5chain, body: [cert_der], type: :secp256r1}}
      end)

      matching_key = %Key{
        name: @sample_key_name,
        namespace: "fdo_owner_keys/#{@sample_realm}/ecdsa-p256",
        alg: :es256,
        public_pem: public_pem
      }

      stub(Secrets, :create_namespace, fn _realm, :es256 ->
        {:ok, "fdo_owner_keys/#{@sample_realm}/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, matching_key} end)

      assert %LoadRequest{owner_key_algorithm: :es256} = from_changeset!(@sample_params)
    end

    test "rejects a key whose EC point is NOT in the x5chain certificate" do
      {voucher, _private_pem} = generate_p256_x509_data_and_pem()
      [cert_der | _] = voucher.cert_chain

      {_other_voucher, other_private_pem} = generate_p256_x509_data_and_pem()
      wrong_public_pem = ec_private_pem_to_public_pem(other_private_pem)

      stub(OVCore, :entry_private_key, fn _entry ->
        {:ok, %PublicKey{encoding: :x5chain, body: [cert_der], type: :secp256r1}}
      end)

      wrong_key = %Key{
        name: @sample_key_name,
        namespace: "fdo_owner_keys/#{@sample_realm}/ecdsa-p256",
        alg: :es256,
        public_pem: wrong_public_pem
      }

      stub(Secrets, :create_namespace, fn _realm, :es256 ->
        {:ok, "fdo_owner_keys/#{@sample_realm}/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, wrong_key} end)

      assert {:error, changeset} = from_changeset(@sample_params)

      assert %{key_name: ["does not match the public key in the ownership voucher's last entry"]} =
               errors_on(changeset)
    end
  end

  describe "changeset/2 with a secp384r1/x5chain voucher" do
    test "parses successfully and sets owner_key_algorithm to :es384" do
      {voucher, private_pem} = generate_p384_x5chain_data_and_pem()
      voucher_pem = voucher_to_pem(voucher)
      public_pem = ec_private_pem_to_public_pem(private_pem)

      x5chain_p384_key = %Key{
        name: @sample_key_name,
        namespace: "fdo_owner_keys/#{@sample_realm}/ecdsa-p384",
        alg: :es384,
        public_pem: public_pem
      }

      stub(Secrets, :create_namespace, fn _realm, :es384 ->
        {:ok, "fdo_owner_keys/#{@sample_realm}/ecdsa-p384"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, x5chain_p384_key} end)

      params = Map.put(@sample_params, "ownership_voucher", voucher_pem)

      assert %LoadRequest{owner_key_algorithm: :es384} = from_changeset!(params)
    end

    test "rejects a mismatched key even with x5chain encoding" do
      {voucher, _private_pem} = generate_p384_x5chain_data_and_pem()
      voucher_pem = voucher_to_pem(voucher)

      {_other_voucher, other_private_pem} = generate_p384_x5chain_data_and_pem()
      wrong_public_pem = ec_private_pem_to_public_pem(other_private_pem)

      wrong_key = %Key{
        name: @sample_key_name,
        namespace: "fdo_owner_keys/#{@sample_realm}/ecdsa-p384",
        alg: :es384,
        public_pem: wrong_public_pem
      }

      stub(Secrets, :create_namespace, fn _realm, :es384 ->
        {:ok, "fdo_owner_keys/#{@sample_realm}/ecdsa-p384"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, wrong_key} end)

      params = Map.put(@sample_params, "ownership_voucher", voucher_pem)

      assert {:error, changeset} = from_changeset(params)

      assert %{key_name: ["does not match the public key in the ownership voucher's last entry"]} =
               errors_on(changeset)
    end
  end

  defp ec_private_pem_to_public_pem(private_pem) do
    [{:ECPrivateKey, priv_der, _}] = :public_key.pem_decode(private_pem)

    {:ECPrivateKey, _version, _priv_bytes, named_curve, pub_point, _} =
      :public_key.der_decode(:ECPrivateKey, priv_der)

    pub_entry =
      :public_key.pem_entry_encode(:SubjectPublicKeyInfo, {{:ECPoint, pub_point}, named_curve})

    :public_key.pem_encode([pub_entry])
  end

  # P-384 SPKI public key, used to test :secp384r1 detection in replacement_public_key.
  @p384_public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAE/d7hrn2G8xmA/TclvzfKGQt9ZM5QjQv9
  JbK0g342jZIKzixJbi/sm0wmLRETRT3NlEKzes/Yb7sL1PJ0RBaGIWZXtIqLv1Dp
  TUcig2gSQptVEOfP15CbfsvMyaQVvvmC
  -----END PUBLIC KEY-----
  """

  # RSA PKCS#1 SubjectPublicKeyInfo PEM (OID 1.2.840.113549.1.1.1).
  @rsa_pkcs1_public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyB/4pewJa3mpxm9SCQBt
  9xfXzntZLcEw3AC5/46+0Smpr9cJP/NcP3maA20jg6KNSMJLb3i97TGkGBdW0Tlf
  q9ZTrnI/zJeyM7nARf8O3LOxdlvGcNvvnCN5EYc5MrDnyBiJp6EvMlrHxirfjmP4
  MdEhTNvOdyzojrl7CVWH3EqoqQwC5up/aAWTT15lzGmQght8goLVm7K4UPdxufPO
  shbKvVI72J8FdeCbYNXtntQZxvIfHZGKgN5/VjZtrHd40OIUJ7Up/GTACqfqutZi
  axmrbJHObcjbeZerF22SYtKRq2QO9falJg/uvutpD6CKV4BNv9l+bfPV0TbJN5Ox
  iwIDAQAB
  -----END PUBLIC KEY-----
  """

  # RSA-PSS SubjectPublicKeyInfo PEM (OID 1.2.840.113549.1.1.10).
  @rsa_pss_public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MIIBIDALBgkqhkiG9w0BAQoDggEPADCCAQoCggEBALvFtCJDMblQGzqFu5as4ppG
  ILk8Uks0plnPnlmRjpoSKmaMXhEMMEvGVTCBu6DL9NFFDLnOefQnvfDvSCmtBXSk
  WDvSQiDYpZhWQLFfcbbSQNYM4R4yqOFajh7zO9SxFULkzFcFP3D4K0s2qggdiKVA
  e/Lri8o0pI4IkorN6yipeKBkxByUUDsjbGvbNOK+GDN1+4yEK5waEgFyMx5e3wix
  LXyI0UFPKjbmYJ677fptOyvOeLTxwPmM8gx71JG+wjycJ5rA2UpCcqzWWk6XZMlV
  PIzy3xRbtDaXQso+p3Iv/GZAkRLYoyA/R0cMevtJ0VDl1l0+X3MrS8XVXdIU+/EC
  AwEAAQ==
  -----END PUBLIC KEY-----
  """

  describe "changeset/2 replacement_public_key validation" do
    setup do
      stub(Secrets, :create_namespace, fn _realm, _alg ->
        {:ok, "fdo_owner_keys/test_realm/ecdsa-p256"}
      end)

      stub(Secrets, :get_key, fn _name, _opts -> {:ok, @sample_secrets_key} end)
      :ok
    end

    test "accepts a P-384 SPKI PEM as `replacement_public_key`" do
      params = Map.put(@sample_params, "replacement_public_key", @p384_public_key_pem)

      assert %LoadRequest{} = from_changeset!(params)
    end

    test "accepts an RSA PKCS#1 SPKI PEM as `replacement_public_key`" do
      params = Map.put(@sample_params, "replacement_public_key", @rsa_pkcs1_public_key_pem)

      assert %LoadRequest{} = from_changeset!(params)
    end

    test "accepts an RSA-PSS SPKI PEM as `replacement_public_key`" do
      params = Map.put(@sample_params, "replacement_public_key", @rsa_pss_public_key_pem)

      assert %LoadRequest{} = from_changeset!(params)
    end
  end
end
