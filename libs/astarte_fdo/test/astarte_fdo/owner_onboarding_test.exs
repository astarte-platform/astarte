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

defmodule Astarte.FDO.OwnerOnboardingTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.FDOSession

  alias Astarte.FDO.Core.Hash
  alias Astarte.FDO.Core.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.FDO.Core.OwnerOnboarding.HelloDevice
  alias Astarte.FDO.Core.OwnerOnboarding.Session
  alias Astarte.FDO.OwnerOnboarding
  alias Astarte.FDO.OwnershipVoucher
  alias COSE.Messages.Sign1

  @max_device_service_info_sz 4096

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
    setup %{hello_device: hello_device} do
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

  describe "fetch_alg/1 with map input" do
    test "returns {:ok, :es256} for algorithm -7" do
      assert {:ok, :es256} = OwnerOnboarding.fetch_alg(%{1 => -7})
    end

    test "returns {:ok, :edsdsa} for algorithm -8" do
      assert {:ok, :edsdsa} = OwnerOnboarding.fetch_alg(%{1 => -8})
    end

    test "returns {:error, :unsupported_alg} for unknown algorithm" do
      assert {:error, :unsupported_alg} = OwnerOnboarding.fetch_alg(%{1 => 999})
    end

    test "returns {:error, :unsupported_alg} when alg key is missing" do
      assert {:error, :unsupported_alg} = OwnerOnboarding.fetch_alg(%{})
    end
  end

  describe "fetch_alg/1 with binary CBOR input" do
    test "decodes CBOR and returns the algorithm" do
      cbor = CBOR.encode(%{1 => -7})
      assert {:ok, :es256} = OwnerOnboarding.fetch_alg(cbor)
    end

    test "returns {:error, :unsupported_alg} for CBOR with unknown algorithm" do
      cbor = CBOR.encode(%{1 => 42})
      assert {:error, :unsupported_alg} = OwnerOnboarding.fetch_alg(cbor)
    end
  end

  describe "build_sig_structure/2" do
    test "returns {:ok, CBOR-encoded sig structure}" do
      protected = CBOR.encode(%{1 => -7})
      payload = :crypto.strong_rand_bytes(32)

      assert {:ok, cbor} = OwnerOnboarding.build_sig_structure(protected, payload)
      assert is_binary(cbor)

      assert {:ok, ["Signature1", ^protected, <<>>, ^payload], ""} = CBOR.decode(cbor)
    end
  end

  describe "ov_next_entry/3" do
    test "returns {:ok, entry} for valid entry_num 0", %{realm: realm_name, guid: guid} do
      cbor_body = CBOR.encode([0])
      assert {:ok, _entry} = OwnerOnboarding.ov_next_entry(cbor_body, realm_name, guid)
    end

    test "returns {:error, :message_body_error} for invalid CBOR body", %{
      realm: realm_name,
      guid: guid
    } do
      assert {:error, :message_body_error} =
               OwnerOnboarding.ov_next_entry(<<0xFF>>, realm_name, guid)
    end

    test "returns error when guid does not match any voucher", %{realm: realm_name} do
      cbor_body = CBOR.encode([0])
      unknown_guid = :crypto.strong_rand_bytes(16)
      assert {:error, _} = OwnerOnboarding.ov_next_entry(cbor_body, realm_name, unknown_guid)
    end
  end
end
