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

  alias Astarte.FDO.Core.OwnerOnboarding.HelloDevice
  alias Astarte.FDO.Core.OwnershipVoucher
  alias Astarte.FDO.OwnerOnboarding
  alias Astarte.Secrets
  alias COSE.Keys
  alias COSE.Messages.Sign1

  import Astarte.FDO.Helpers

  setup_all %{realm_name: realm_name} do
    {voucher_p256_x509, key_p256_x509} = generate_p256_x509_data_and_pem()
    {:ok, key_p256_x509} = Keys.from_pem(key_p256_x509)
    cbor_p256_x509 = OwnershipVoucher.cbor_encode(voucher_p256_x509)
    id_p256_x509 = voucher_p256_x509.header.guid
    key_alg = :es256
    key_name = "ECDH256_X509_#{System.unique_integer([:positive])}"
    {:ok, namespace} = Secrets.create_namespace(realm_name, key_alg)

    :ok = Secrets.import_key(key_name, key_alg, key_p256_x509, namespace: namespace)
    {:ok, key_p256_x509} = Secrets.get_key(key_name, namespace: namespace)

    attrs = %{
      key_name: key_name,
      key_algoright: key_alg,
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
    cbor_p384_x509 = OwnershipVoucher.cbor_encode(voucher_p384_x509)
    id_p384_x509 = voucher_p384_x509.header.guid

     :ok = Secrets.import_key(key_name, key_alg, key_p384_x509, namespace: namespace)
    {:ok, key_p384_x509} = Secrets.get_key(key_name, namespace: namespace)

    attrs = %{
      key_name: key_name,
      key_algoright: key_alg,
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
    cbor_p256_chain = OwnershipVoucher.cbor_encode(voucher_p256_chain)
    id_p256_chain = voucher_p256_chain.header.guid
    {:ok, namespace} = Astarte.Secrets.create_namespace(realm_name, key_alg)

     :ok = Secrets.import_key(key_name, key_alg, key_p256_chain, namespace: namespace)
    {:ok, key_p256_chain} = Secrets.get_key(key_name, namespace: namespace)

    attrs = %{
      key_name: key_name,
      key_algoright: key_alg,
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
    cbor_p384_chain = OwnershipVoucher.cbor_encode(voucher_p384_chain)
    id_p384_chain = voucher_p384_chain.header.guid
    {:ok, namespace} = Astarte.Secrets.create_namespace(realm_name, key_alg)

     :ok = Secrets.import_key(key_name, key_alg, key_p384_chain, namespace: namespace)
    {:ok, key_p384_chain} = Secrets.get_key(key_name, namespace: namespace)

    attrs = %{
      key_name: key_name,
      key_algoright: key_alg,
      voucher_data: cbor_p384_chain,
      guid: id_p384_chain
    }

    insert_voucher(realm_name, attrs)

    hello_msg_p384_x5chain =
      HelloDevice.generate(guid: id_p384_chain, kex_name: "ECDH384", easig_info: :es384)

    cbor_hello_p384_x5chain = HelloDevice.cbor_encode(hello_msg_p384_x5chain)

    %{
      p256_x509: %{id: id_p256_x509, cbor_hello: cbor_hello_p256_x509},
      p256_chain: %{id: id_p256_chain, cbor_hello: cbor_hello_p256_chain},
      p384_x509: %{id: id_p384_x509, cbor_hello: cbor_hello_p384_x509},
      p384_chain: %{id: id_p384_chain, cbor_hello: cbor_hello_p384_x5chain}
    }
  end

  describe "hello_device/2" do
    test "P-256 Flow: negotiates ECDH256 and ES256", %{realm_name: realm_name, p256_x509: ctx} do
      assert {:ok, token, resp_binary} =
               OwnerOnboarding.hello_device(realm_name, ctx.cbor_hello)

      assert is_binary(token)
      assert {:ok, sign1_msg} = Sign1.decode_cbor(resp_binary)
      assert sign1_msg.phdr.alg == :es256
    end

    test "P-384 Flow: negotiates ECDH384 and ES384", %{realm_name: realm_name, p384_x509: ctx} do
      assert {:ok, token, resp_binary} =
               OwnerOnboarding.hello_device(realm_name, ctx.cbor_hello)

      assert is_binary(token)
      assert {:ok, sign1_msg} = Sign1.decode_cbor(resp_binary)
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
    assert {:ok, sign1_msg} = Sign1.decode_cbor(resp_binary)
    assert sign1_msg.phdr.alg == :es256
  end

  test "P-384 with X5CHAIN: extracts key from P-384 certificate chain", %{
    realm: realm_name,
    p384_chain: ctx
  } do
    assert {:ok, token, resp_binary} =
             OwnerOnboarding.hello_device(realm_name, ctx.cbor_hello)

    assert is_binary(token)
    assert {:ok, sign1_msg} = Sign1.decode_cbor(resp_binary)
    assert sign1_msg.phdr.alg == :es384
  end
end
