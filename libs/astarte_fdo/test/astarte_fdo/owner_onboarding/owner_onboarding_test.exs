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

defmodule Astarte.FDO.OwnerOnboarding.OwnerOnboardingTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.FDOSession

  alias Astarte.FDO.Core.Hash
  alias Astarte.FDO.Core.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.FDO.Core.OwnerOnboarding.HelloDevice
  alias Astarte.FDO.Core.OwnerOnboarding.Session
  alias Astarte.FDO.Core.OwnershipVoucher, as: OVCore
  alias Astarte.FDO.OwnerOnboarding
  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.Secrets
  alias COSE.Keys
  alias COSE.Messages.Sign1

  import Astarte.FDO.Helpers

  @max_device_service_info_sz 4096

  setup_all %{realm_name: realm_name} do
    {voucher_p256_x509, key_p256_x509} = generate_p256_x509_data_and_pem()
    {:ok, key_p256_x509} = Keys.from_pem(key_p256_x509)
    cbor_p256_x509 = OVCore.cbor_encode(voucher_p256_x509)
    id_p256_x509 = voucher_p256_x509.header.guid
    key_alg = :es256
    key_name = "ECDH256_X509_#{System.unique_integer([:positive])}"
    {:ok, namespace} = Secrets.create_namespace(realm_name, key_alg)

    :ok = Secrets.import_key(key_name, key_alg, key_p256_x509, namespace: namespace)
    {:ok, _key_p256_x509} = Secrets.get_key(key_name, namespace: namespace)

    attrs = %{
      key_name: key_name,
      key_algorithm: key_alg,
      voucher_data: cbor_p256_x509,
      guid: id_p256_x509
    }

    insert_voucher(realm_name, attrs)

    hello_msg_p256_x509 =
      HelloDevice.generate(guid: id_p256_x509, kex_name: "ECDH256", easig_info: :es256)

    cbor_hello_p256_x509 = HelloDevice.cbor_encode(hello_msg_p256_x509)

    key_alg = :es384
    key_name = "ECDH384_X509_#{System.unique_integer([:positive])}"

    {voucher_p384_x509, key_p384_x509} = generate_p384_x509_data_and_pem()
    {:ok, key_p384_x509} = Keys.from_pem(key_p384_x509)
    cbor_p384_x509 = OVCore.cbor_encode(voucher_p384_x509)
    id_p384_x509 = voucher_p384_x509.header.guid

    {:ok, namespace} = Secrets.create_namespace(realm_name, key_alg)

    :ok = Secrets.import_key(key_name, key_alg, key_p384_x509, namespace: namespace)
    {:ok, _key_p384_x509} = Secrets.get_key(key_name, namespace: namespace)

    attrs = %{
      key_name: key_name,
      key_algorithm: key_alg,
      voucher_data: cbor_p384_x509,
      guid: id_p384_x509
    }

    insert_voucher(realm_name, attrs)

    hello_msg_p384_x509 =
      HelloDevice.generate(guid: id_p384_x509, kex_name: "ECDH384", easig_info: :es384)

    cbor_hello_p384_x509 = HelloDevice.cbor_encode(hello_msg_p384_x509)

    key_alg = :es256
    key_name = "ECDH256_X5CHAIN_#{System.unique_integer([:positive])}"
    {voucher_p256_chain, key_p256_chain} = generate_p256_x5chain_data_and_pem()
    {:ok, key_p256_chain} = Keys.from_pem(key_p256_chain)
    cbor_p256_chain = OVCore.cbor_encode(voucher_p256_chain)
    id_p256_chain = voucher_p256_chain.header.guid
    {:ok, namespace} = Astarte.Secrets.create_namespace(realm_name, key_alg)

    :ok = Secrets.import_key(key_name, key_alg, key_p256_chain, namespace: namespace)
    {:ok, _key_p256_chain} = Secrets.get_key(key_name, namespace: namespace)

    attrs = %{
      key_name: key_name,
      key_algorithm: key_alg,
      voucher_data: cbor_p256_chain,
      guid: id_p256_chain
    }

    insert_voucher(realm_name, attrs)

    hello_msg_p256_x5chain =
      HelloDevice.generate(guid: id_p256_chain, kex_name: "ECDH256", easig_info: :es256)

    cbor_hello_p256_chain = HelloDevice.cbor_encode(hello_msg_p256_x5chain)
    key_alg = :es384
    key_name = "ECDH384_X5CHAIN_#{System.unique_integer([:positive])}"

    {voucher_p384_chain, key_p384_chain} = generate_p384_x5chain_data_and_pem()
    {:ok, key_p384_chain} = Keys.from_pem(key_p384_chain)
    cbor_p384_chain = OVCore.cbor_encode(voucher_p384_chain)
    id_p384_chain = voucher_p384_chain.header.guid
    {:ok, namespace} = Astarte.Secrets.create_namespace(realm_name, key_alg)

    :ok = Secrets.import_key(key_name, key_alg, key_p384_chain, namespace: namespace)
    {:ok, _key_p384_chain} = Secrets.get_key(key_name, namespace: namespace)

    attrs = %{
      key_name: key_name,
      key_algorithm: key_alg,
      voucher_data: cbor_p384_chain,
      guid: id_p384_chain
    }

    insert_voucher(realm_name, attrs)

    hello_msg_p384_x5chain =
      HelloDevice.generate(guid: id_p384_chain, kex_name: "ECDH384", easig_info: :es384)

    cbor_hello_p384_x5chain = HelloDevice.cbor_encode(hello_msg_p384_x5chain)

    %{
      p256_x509: %{id: id_p256_x509, cbor_hello: cbor_hello_p256_x509, key_struct: key_p256_x509},
      p256_chain: %{
        id: id_p256_chain,
        cbor_hello: cbor_hello_p256_chain,
        key_struct: key_p256_chain
      },
      p384_x509: %{id: id_p384_x509, cbor_hello: cbor_hello_p384_x509, key_struct: key_p384_x509},
      p384_chain: %{
        id: id_p384_chain,
        cbor_hello: cbor_hello_p384_x5chain,
        key_struct: key_p384_chain
      }
    }
  end

  describe "hello_device/2" do
    test "P-256 Flow: negotiates ECDH256 and ES256", %{realm_name: realm_name, p256_x509: ctx} do
      assert {:ok, token, resp_binary} =
               OwnerOnboarding.hello_device(realm_name, ctx.cbor_hello)

      assert is_binary(token)
      assert {:ok, sign1_msg} = Sign1.verify_decode(resp_binary, ctx.key_struct)
      assert sign1_msg.phdr.alg == :es256
    end

    test "P-384 Flow: negotiates ECDH384 and ES384", %{realm_name: realm_name, p384_x509: ctx} do
      assert {:ok, token, resp_binary} =
               OwnerOnboarding.hello_device(realm_name, ctx.cbor_hello)

      assert is_binary(token)
      assert {:ok, sign1_msg} = Sign1.verify_decode(resp_binary, ctx.key_struct)
      assert sign1_msg.phdr.alg == :es384
    end
  end

  test "P-256 with X5CHAIN: extracts key from certificate chain", %{
    realm_name: realm_name,
    p256_chain: ctx
  } do
    assert {:ok, token, resp_binary} =
             OwnerOnboarding.hello_device(realm_name, ctx.cbor_hello)

    assert is_binary(token)
    assert {:ok, sign1_msg} = Sign1.verify_decode(resp_binary, ctx.key_struct)
    assert sign1_msg.phdr.alg == :es256
  end

  test "P-384 with X5CHAIN: extracts key from P-384 certificate chain", %{
    realm_name: realm_name,
    p384_chain: ctx
  } do
    assert {:ok, token, resp_binary} =
             OwnerOnboarding.hello_device(realm_name, ctx.cbor_hello)

    assert is_binary(token)
    assert {:ok, sign1_msg} = Sign1.verify_decode(resp_binary, ctx.key_struct)
    assert sign1_msg.phdr.alg == :es384
  end

  describe "build_owner_service_info_ready/3" do
    @tag :skip
    # TODO: re-enable this test when credential reuse logic is implemented.
    test "successfully processes DeviceServiceInfoReady, creates new voucher, and returns OwnerServiceInfoReady",
         %{
           realm: realm_name,
           session: session
         } do
      new_hmac_value = :crypto.strong_rand_bytes(32)
      new_hmac = %Hash{type: :hmac_sha256, hash: new_hmac_value}
      device_max_size = 2048

      assert {:ok, session, response} =
               OwnerOnboarding.build_owner_service_info_ready(
                 realm_name,
                 session,
                 %DeviceServiceInfoReady{
                   replacement_hmac: new_hmac,
                   max_owner_service_info_sz: device_max_size
                 }
               )

      assert session.replacement_hmac == new_hmac
      assert OwnershipVoucher.credential_reuse?(session) == false

      assert response == [@max_device_service_info_sz]
    end

    test "handles Credential Reuse (nil HMAC) correctly", %{
      realm_name: realm_name,
      session: session
    } do
      session = %{session | replacement_guid: session.guid}

      assert {:ok, session, _result} =
               OwnerOnboarding.build_owner_service_info_ready(
                 realm_name,
                 session,
                 %DeviceServiceInfoReady{
                   replacement_hmac: nil,
                   max_owner_service_info_sz: 2048
                 }
               )

      assert OwnershipVoucher.credential_reuse?(session) == true
    end

    test "handles the default recommended limit(nil info size) correctly", %{
      realm_name: realm_name,
      session: session
    } do
      new_hmac = :crypto.strong_rand_bytes(32)

      assert {:ok, _, _result} =
               OwnerOnboarding.build_owner_service_info_ready(
                 realm_name,
                 session,
                 %DeviceServiceInfoReady{
                   replacement_hmac: %Hash{hash: new_hmac, type: :hmac_sha256},
                   max_owner_service_info_sz: nil
                 }
               )
    end

    test "handles the default recommended limit(0 info size) correctly", %{
      realm_name: realm_name,
      session: session
    } do
      new_hmac = :crypto.strong_rand_bytes(32)

      assert {:ok, _, _result} =
               OwnerOnboarding.build_owner_service_info_ready(
                 realm_name,
                 session,
                 %DeviceServiceInfoReady{
                   replacement_hmac: %Hash{hash: new_hmac, type: :hmac_sha256},
                   max_owner_service_info_sz: 0
                 }
               )
    end

    test "returns error for wrong session", %{
      realm_name: realm_name
    } do
      new_hmac = :crypto.strong_rand_bytes(32)

      assert {:error, :failed_66} =
               OwnerOnboarding.build_owner_service_info_ready(
                 realm_name,
                 %Session{guid: :crypto.strong_rand_bytes(16)},
                 %DeviceServiceInfoReady{
                   replacement_hmac: %Hash{hash: new_hmac, type: :hmac_sha256},
                   max_owner_service_info_sz: 0
                 }
               )
    end
  end

  describe "generate_rsa_2048_key/0" do
    test "returns an RSA private key record" do
      key = OwnerOnboarding.generate_rsa_2048_key()
      assert {:RSAPrivateKey, _, _, _, _, _, _, _, _, _, _} = key
    end
  end

  describe "get_public_key/1" do
    test "returns {:ok, RSAPublicKey} for a valid RSA private key record" do
      private_key = OwnerOnboarding.generate_rsa_2048_key()

      assert {:ok, {:RSAPublicKey, modulus, public_exponent}} =
               OwnerOnboarding.get_public_key(private_key)

      assert is_integer(modulus)
      assert is_integer(public_exponent)
    end

    test "returns {:error, :invalid_private_key_format} for invalid input" do
      assert {:error, :invalid_private_key_format} = OwnerOnboarding.get_public_key("not_a_key")
      assert {:error, :invalid_private_key_format} = OwnerOnboarding.get_public_key(nil)
      assert {:error, :invalid_private_key_format} = OwnerOnboarding.get_public_key(%{})
    end
  end

  describe "ov_next_entry/3" do
    test "returns {:ok, entry} for valid entry_num 0", %{realm_name: realm_name, device_id: guid} do
      cbor_body = CBOR.encode([0])
      assert {:ok, _entry} = OwnerOnboarding.ov_next_entry(cbor_body, realm_name, guid)
    end

    test "returns {:error, :message_body_error} for invalid CBOR body", context do
      %{realm_name: realm_name, device_id: guid} = context

      assert {:error, :message_body_error} =
               OwnerOnboarding.ov_next_entry(<<0xFF>>, realm_name, guid)
    end

    test "returns error when guid does not match any voucher", %{realm_name: realm_name} do
      cbor_body = CBOR.encode([0])
      unknown_guid = :crypto.strong_rand_bytes(16)
      assert {:error, _} = OwnerOnboarding.ov_next_entry(cbor_body, realm_name, unknown_guid)
    end
  end
end
