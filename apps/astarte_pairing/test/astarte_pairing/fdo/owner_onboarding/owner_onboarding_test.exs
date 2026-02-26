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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.OwnerOnboardingTest do
  use Astarte.Cases.Data, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding
  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias COSE.Messages.Sign1
  alias Astarte.Pairing.FDO.OwnershipVoucher

  import Astarte.Helpers.FDO

  setup_all %{realm_name: realm_name} do
    {voucher_p256_x509, key_p256_x509} = generate_p256_x509_data_and_pem()
    cbor_p256_x509 = OwnershipVoucher.cbor_encode(voucher_p256_x509)
    id_p256_x509 = voucher_p256_x509.header.guid
    insert_voucher(realm_name, key_p256_x509, cbor_p256_x509, id_p256_x509)

    hello_msg_p256_x509 =
      HelloDevice.generate(guid: id_p256_x509, kex_name: "ECDH256", easig_info: :es256)

    cbor_hello_p256_x509 = HelloDevice.cbor_encode(hello_msg_p256_x509)

    {voucher_p384_x509, key_p384_x509} = generate_p384_x509_data_and_pem()
    cbor_p384_x509 = OwnershipVoucher.cbor_encode(voucher_p384_x509)
    id_p384_x509 = voucher_p384_x509.header.guid
    insert_voucher(realm_name, key_p384_x509, cbor_p384_x509, id_p384_x509)

    hello_msg_p384_x509 =
      HelloDevice.generate(guid: id_p384_x509, kex_name: "ECDH384", easig_info: :es384)

    cbor_hello_p384_x509 = HelloDevice.cbor_encode(hello_msg_p384_x509)

    {voucher_p256_chain, key_p256_chain} = generate_p256_x5chain_data_and_pem()
    cbor_p256_chain = OwnershipVoucher.cbor_encode(voucher_p256_chain)
    id_p256_chain = voucher_p256_chain.header.guid
    insert_voucher(realm_name, key_p256_chain, cbor_p256_chain, id_p256_chain)

    hello_msg_p256_x5chain =
      HelloDevice.generate(guid: id_p256_chain, kex_name: "ECDH256", easig_info: :es256)

    cbor_hello_p256_chain = HelloDevice.cbor_encode(hello_msg_p256_x5chain)

    {voucher_p384_chain, key_p384_chain} = generate_p384_x5chain_data_and_pem()
    cbor_p384_chain = OwnershipVoucher.cbor_encode(voucher_p384_chain)
    id_p384_chain = voucher_p384_chain.header.guid
    insert_voucher(realm_name, key_p384_chain, cbor_p384_chain, id_p384_chain)

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
