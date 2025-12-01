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

  import Astarte.Helpers.FDO

  @es256_alg -7
  @edsdsa_alg -8

  @test_nonce :crypto.strong_rand_bytes(16)
  @test_guid :crypto.strong_rand_bytes(16)
  @test_session_key :crypto.strong_rand_bytes(32)

  def generate_es256_keys do
    COSE.Keys.ECC.generate(:es256)
  end

  defp build_test_cose_sign1(alg_id, priv_key_struct, nonce_val, guid_val) do
    eat_claims = %{
      10 => nonce_val,
      256 => guid_val
    }

    payload_bin = CBOR.encode(eat_claims)

    COSE.Messages.Sign1.sign_encode_cbor(
      %COSE.Messages.Sign1{payload: payload_bin, phdr: %{alg: :es256}, uhdr: %{}},
      priv_key_struct
    )
  end

  defp sign_data(@es256_alg, priv_key_input, data) do
    key_arg =
      case priv_key_input do
        %COSE.Keys.ECC{d: d} -> [d, :secp256r1]
        binary when is_binary(binary) -> [binary, :secp256r1]
        other -> other
      end

    der_signature = :crypto.sign(:ecdsa, :sha256, data, key_arg)
    der_to_raw_es256(der_signature)
  end

  defp sign_data(@edsdsa_alg, priv_key_raw, data) do
    :crypto.sign(:eddsa, :none, data, [priv_key_raw, :ed25519])
  end

  defp der_to_raw_es256(der) do
    {:"ECDSA-Sig-Value", r, s} = :public_key.der_decode(:"ECDSA-Sig-Value", der)
    pad_to_32(r) <> pad_to_32(s)
  end

  defp pad_to_32(int) do
    bin = :binary.encode_unsigned(int)

    case 32 - byte_size(bin) do
      0 -> bin
      n when n > 0 -> <<0::size(n)-unit(8), bin::binary>>
      _ -> bin
    end
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

    body = build_test_cose_sign1(@es256_alg, key, @test_nonce, @test_guid)

    creds = dummy_creds(COSE.Keys.ECC.public_key(key), key)

    {:ok, msg_65_payload} =
      OwnerOnboarding.verify(
        body,
        key,
        @test_nonce,
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
    body = build_test_cose_sign1(@es256_alg, key, wrong_nonce, @test_guid)
    creds = dummy_creds(COSE.Keys.ECC.public_key(key), key)

    assert {:error, :invalid_signature} =
             OwnerOnboarding.verify(
               body,
               key,
               @test_nonce,
               @test_guid,
               creds
             )
  end

  test "verify ES256 fails if Device ID (GUID) does not match" do
    key = generate_es256_keys()

    body = build_test_cose_sign1(@es256_alg, key, @test_nonce, "wrong-guid")

    creds = dummy_creds(COSE.Keys.ECC.public_key(key), key)

    assert {:error, :invalid_signature} =
             OwnerOnboarding.verify(
               body,
               key,
               @test_nonce,
               @test_guid,
               creds
             )
  end

  test "verify ES256 fails with wrong public key" do
    key = generate_es256_keys()
    key2 = generate_es256_keys()

    body = build_test_cose_sign1(@es256_alg, key, @test_nonce, @test_guid)

    creds = dummy_creds(COSE.Keys.ECC.public_key(key2), key)

    assert {:error, :invalid_signature} =
             OwnerOnboarding.verify(
               body,
               key2,
               @test_nonce,
               @test_guid,
               creds
             )
  end
end
