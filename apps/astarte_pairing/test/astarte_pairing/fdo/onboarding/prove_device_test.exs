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
  use ExUnit.Case
  alias Astarte.Pairing.FDO.OwnerOnboarding

  @es256_alg -7

  @test_prove_dv_nonce :crypto.strong_rand_bytes(16)
  @test_setup_dv_nonce :crypto.strong_rand_bytes(16)
  @test_guid :crypto.strong_rand_bytes(16)

  def generate_es256_keys do
    COSE.Keys.ECC.generate(:es256)
  end

  defp build_test_cose_sign1(
         _alg_id,
         priv_key_struct,
         prove_dv_nonce_val,
         setup_dv_nonce_val,
         guid_val
       ) do
    # ProveDvNonce is in payload

    ueid = <<1>> <> guid_val
    ueid = COSE.tag_as_byte(ueid)

    eat_claims = %{
      10 => COSE.tag_as_byte(prove_dv_nonce_val),
      256 => ueid,
      -257 => [COSE.tag_as_byte(<<>>)]
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

  defp dummy_creds(owner_pub_key, owner_private_key) do
    %{
      guid: @test_guid,
      rendezvous_info: [[2, 8080, "localhost"]],
      owner_pub_key: owner_pub_key,
      device_info: "test",
      owner_private_key: owner_private_key
    }
  end

  test "verify ES256 signature success and returns Msg 65" do
    key = generate_es256_keys()

    body =
      build_test_cose_sign1(
        @es256_alg,
        key,
        @test_prove_dv_nonce,
        @test_setup_dv_nonce,
        @test_guid
      )

    creds = dummy_creds(COSE.Keys.ECC.public_key(key), key)

    {:ok, %{setup_dv_nonce: @test_setup_dv_nonce, resp: msg_65_payload}} =
      OwnerOnboarding.verify_and_build_response(
        body,
        {:es256, key},
        @test_prove_dv_nonce,
        @test_guid,
        creds
      )

    assert {
             :ok,
             %CBOR.Tag{tag: 18, value: _},
             ""
           } = CBOR.decode(msg_65_payload)
  end

  test "verify ES256 fails if Nonce does not match" do
    key = generate_es256_keys()

    wrong_nonce = :crypto.strong_rand_bytes(16)
    body = build_test_cose_sign1(@es256_alg, key, wrong_nonce, @test_setup_dv_nonce, @test_guid)
    creds = dummy_creds(COSE.Keys.ECC.public_key(key), key)

    assert {:error, :prove_dv_nonce_mismatch} =
             OwnerOnboarding.verify_and_build_response(
               body,
               {:es256, key},
               @test_prove_dv_nonce,
               @test_guid,
               creds
             )
  end

  test "verify ES256 fails if Device ID (GUID) does not match" do
    key = generate_es256_keys()

    body =
      build_test_cose_sign1(
        @es256_alg,
        key,
        @test_prove_dv_nonce,
        @test_setup_dv_nonce,
        "wrong-guid"
      )

    creds = dummy_creds(COSE.Keys.ECC.public_key(key), key)

    assert {:error, :message_body_error} =
             OwnerOnboarding.verify_and_build_response(
               body,
               {:es256, key},
               @test_prove_dv_nonce,
               @test_guid,
               creds
             )
  end

  test "verify ES256 fails with wrong public key" do
    key = generate_es256_keys()
    key2 = generate_es256_keys()

    body =
      build_test_cose_sign1(
        @es256_alg,
        key,
        @test_prove_dv_nonce,
        @test_setup_dv_nonce,
        @test_guid
      )

    creds = dummy_creds(COSE.Keys.ECC.public_key(key2), key)

    assert :error =
             OwnerOnboarding.verify_and_build_response(
               body,
               {:es256, key2},
               @test_prove_dv_nonce,
               @test_guid,
               creds
             )
  end
end
