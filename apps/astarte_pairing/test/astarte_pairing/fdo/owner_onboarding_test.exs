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

defmodule Astarte.Pairing.FDO.OwnerOnboardingTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Astarte.Cases.FDOSession
  doctest Astarte.Pairing.FDO.OwnerOnboarding

  alias Astarte.Pairing.FDO.OwnerOnboarding
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias COSE.Messages.Sign1
  alias Astarte.Pairing.FDO.Types.Hash
  alias Astarte.Pairing.FDO.OwnershipVoucher

  @max_device_service_info_sz 4096

  describe "build_owner_service_info_ready/3" do
    setup %{
      realm: realm_name,
      session: session,
      owner_key_pem: owner_key_pem,
      cbor_ownership_voucher: cbor_ownership_voucher
    } do
      insert_voucher(realm_name, owner_key_pem, cbor_ownership_voucher, session.guid)
      %{realm: realm_name, session: session}
    end

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
      realm: realm_name,
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
      realm: realm_name,
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
      realm: realm_name,
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
      realm: realm_name
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

  describe "hello_device/2" do
    setup %{
      realm: realm_name,
      owner_key_pem: owner_key_pem,
      cbor_ownership_voucher: cbor_ownership_voucher,
      session: session,
      hello_device: hello_device
    } do
      insert_voucher(realm_name, owner_key_pem, cbor_ownership_voucher, session.guid)
      %{cbor_hello_device: HelloDevice.cbor_encode(hello_device)}
    end

    @tag owner_key: "EC256"
    test "returns a correct ProveOVHdr message signed with EC256 owner key",
         %{
           realm_name: realm_name,
           cbor_hello_device: cbor_hello_device,
           owner_key: owner_key
         } do
      assert {:ok, session_key, prove_ovhdr_bin} =
               OwnerOnboarding.hello_device(realm_name, cbor_hello_device)

      assert is_binary(session_key)

      assert {:ok, %Sign1{} = prove_ovhdr_dec} =
               Sign1.verify_decode(prove_ovhdr_bin, owner_key)

      assert prove_ovhdr_dec.phdr.alg == :es256
    end

    @tag owner_key: "EC384"
    test "returns a correct ProveOVHdr message signed with EC384 owner key",
         %{
           realm_name: realm_name,
           cbor_hello_device: cbor_hello_device,
           owner_key: owner_key
         } do
      assert {:ok, session_key, prove_ovhdr_bin} =
               OwnerOnboarding.hello_device(realm_name, cbor_hello_device)

      assert is_binary(session_key)

      assert {:ok, %Sign1{} = prove_ovhdr_dec} =
               Sign1.verify_decode(prove_ovhdr_bin, owner_key)

      assert prove_ovhdr_dec.phdr.alg == :es384
    end

    @tag owner_key: "RSA2048"
    test "returns a correct ProveOVHdr message signed with RSA2048 owner key",
         %{
           realm_name: realm_name,
           cbor_hello_device: cbor_hello_device,
           owner_key: owner_key
         } do
      assert {:ok, session_key, prove_ovhdr_bin} =
               OwnerOnboarding.hello_device(realm_name, cbor_hello_device)

      assert is_binary(session_key)

      assert {:ok, %Sign1{} = prove_ovhdr_dec} =
               Sign1.verify_decode(prove_ovhdr_bin, owner_key)

      assert prove_ovhdr_dec.phdr.alg == :rs256
    end

    @tag owner_key: "RSA3072"
    test "returns a correct ProveOVHdr message signed with RSA3072 owner key",
         %{
           realm_name: realm_name,
           cbor_hello_device: cbor_hello_device,
           owner_key: owner_key
         } do
      assert {:ok, session_key, prove_ovhdr_bin} =
               OwnerOnboarding.hello_device(realm_name, cbor_hello_device)

      assert is_binary(session_key)

      assert {:ok, %Sign1{} = prove_ovhdr_dec} =
               Sign1.verify_decode(prove_ovhdr_bin, owner_key)

      assert prove_ovhdr_dec.phdr.alg == :rs384
    end
  end
end
