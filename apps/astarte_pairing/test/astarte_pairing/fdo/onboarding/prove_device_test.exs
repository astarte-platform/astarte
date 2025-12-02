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
defmodule Astarte.Pairing.OwnerOnboarding.Onboarding.ProveDevice do
  use Astarte.Cases.Data, async: true
  alias Astarte.Pairing.FDO.OwnerOnboarding
  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey
  alias Astarte.Pairing.FDO.Types.PublicKey

  import Astarte.Helpers.FDO

  @es256_alg -7

  @test_prove_dv_nonce :crypto.strong_rand_bytes(16)
  @test_setup_dv_nonce :crypto.strong_rand_bytes(16)
  @test_guid :crypto.strong_rand_bytes(16)

  setup_all do
    hello_device = HelloDevice.generate()
    ownership_voucher = sample_ownership_voucher()
    owner_key = sample_extracted_private_key()
    device_key = COSE.Keys.ECC.generate(:es256)
    {:ok, device_random, xb} = SessionKey.new(hello_device.kex_name, device_key)

    %{
      hello_device: hello_device,
      ownership_voucher: ownership_voucher,
      owner_key: owner_key,
      device_key: device_key,
      device_random: device_random,
      xb: xb
    }
  end

  setup context do
    %{
      astarte_instance_id: astarte_instance_id,
      hello_device: hello_device,
      ownership_voucher: ownership_voucher,
      realm: realm_name,
      owner_key: owner_key,
      device_key: key
    } = context

    {:ok, session} =
      Session.new(realm_name, hello_device, ownership_voucher, owner_key)

    session = %{session | device_signature: {:es256, key}}

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      delete_session(realm_name, session.key)
    end)

    %{session: session}
  end

  def generate_es256_keys do
    COSE.Keys.ECC.generate(:es256)
  end

  defp build_test_cose_sign1(
         _alg_id,
         priv_key_struct,
         prove_dv_nonce_val,
         setup_dv_nonce_val,
         guid_val,
         xb
       ) do
    # ProveDvNonce is in payload

    ueid = <<1>> <> guid_val
    ueid = COSE.tag_as_byte(ueid)

    eat_claims = %{
      10 => COSE.tag_as_byte(prove_dv_nonce_val),
      256 => ueid,
      -257 => [COSE.tag_as_byte(xb)]
    }

    payload_bin = CBOR.encode(eat_claims) |> COSE.tag_as_byte()

    COSE.Messages.Sign1.sign_encode_cbor(
      %COSE.Messages.Sign1{
        payload: payload_bin,
        phdr: %{alg: :es256},
        # SetupDvNonce is in unencrypted hdrs
        uhdr: %{-259 => COSE.tag_as_byte(setup_dv_nonce_val)}
      },
      priv_key_struct
    )
  end

  defp dummy_creds() do
    owner_key = sample_extracted_private_key()
    pub_key = COSE.Keys.ECC.public_key(owner_key)

    pub_key =
      %PublicKey{type: :secp256r1, encoding: :x509, body: pub_key}

    %{
      guid: @test_guid,
      rendezvous_info: [[2, 8080, "localhost"]],
      owner_pub_key: pub_key,
      device_info: "test",
      owner_private_key: owner_key
    }
  end

  test "verify ES256 signature success and returns Msg 65", context do
    %{realm_name: realm_name, session: session, device_key: key, xb: xb} = context

    body =
      build_test_cose_sign1(
        @es256_alg,
        key,
        session.prove_dv_nonce,
        @test_setup_dv_nonce,
        session.device_id,
        xb
      )

    creds = dummy_creds()

    COSE.Messages.Sign1.verify_decode(body, key)

    {:ok, %{setup_dv_nonce: @test_setup_dv_nonce, resp: msg_65_payload}} =
      OwnerOnboarding.verify_and_build_response(
        realm_name,
        session,
        body,
        creds
      )

    assert %CBOR.Tag{tag: 18, value: _} = msg_65_payload
  end

  test "verify ES256 fails if Nonce does not match", context do
    %{realm_name: realm_name, session: session, device_key: key, xb: xb} = context

    wrong_nonce = :crypto.strong_rand_bytes(16)

    body =
      build_test_cose_sign1(
        @es256_alg,
        key,
        wrong_nonce,
        @test_setup_dv_nonce,
        session.device_id,
        xb
      )

    creds = dummy_creds()

    assert {:error, :prove_dv_nonce_mismatch} =
             OwnerOnboarding.verify_and_build_response(
               realm_name,
               session,
               body,
               creds
             )
  end

  test "verify ES256 fails if Device ID (GUID) does not match", context do
    %{realm_name: realm_name, session: session, device_key: key, xb: xb} = context

    body =
      build_test_cose_sign1(
        @es256_alg,
        key,
        session.prove_dv_nonce,
        @test_setup_dv_nonce,
        "wrong-guid",
        xb
      )

    creds = dummy_creds()

    assert {:error, :message_body_error} =
             OwnerOnboarding.verify_and_build_response(
               realm_name,
               session,
               body,
               creds
             )
  end

  test "verify ES256 fails with wrong public key", context do
    %{realm_name: realm_name, session: session, xb: xb} = context
    key2 = generate_es256_keys()

    body =
      build_test_cose_sign1(
        @es256_alg,
        key2,
        session.prove_dv_nonce,
        @test_setup_dv_nonce,
        session.device_id,
        xb
      )

    creds = dummy_creds()

    assert :error =
             OwnerOnboarding.verify_and_build_response(
               realm_name,
               session,
               body,
               creds
             )
  end
end
