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
  use Astarte.Cases.FDOSession
  alias Astarte.Pairing.FDO.OwnerOnboarding.ProveDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding
  alias Astarte.Pairing.FDO.OwnerOnboarding.EAToken
  alias Astarte.Pairing.FDO.Types.PublicKey
  alias COSE.Keys.{ECC, RSA}

  @test_setup_dv_nonce :crypto.strong_rand_bytes(16)
  @test_guid :crypto.strong_rand_bytes(16)

  setup context do
    prove_device_data = ProveDevice.generate()
    prove_device_msg = prove_device_data |> ProveDevice.encode_sign(context.device_key)

    %{
      prove_device_data: prove_device_data,
      prove_device_msg: prove_device_msg
    }
  end

  describe "encode_sign/2 and decode/2 symmetry" do
    test "encode and decode are symmetric operations", _context do
      device_priv_key = COSE.Keys.ECC.generate(:es256)

      original_data = ProveDevice.generate()

      encoded_msg = ProveDevice.encode_sign(original_data, device_priv_key)
      assert {:ok, decoded_data} = ProveDevice.decode(encoded_msg, device_priv_key)

      assert decoded_data.xb_key_exchange == original_data.xb_key_exchange
      assert decoded_data.nonce_to2_prove_dv == original_data.nonce_to2_prove_dv
      assert decoded_data.nonce_to2_setup_dv == original_data.nonce_to2_setup_dv
      assert decoded_data.guid == original_data.guid
      assert decoded_data.raw_eat_token == encoded_msg
    end
  end

  describe "decode/2" do
    test "correctly decodes a ProveDevice message coming from device", context do
      assert {:ok, prove_device_decoded} =
               ProveDevice.decode(context.prove_device_msg, context.device_key)

      # check equality of decoded and original data, ignoring raw_eat_token entry (used only for audit purposes)
      assert Map.equal?(
               prove_device_decoded |> Map.delete(:raw_eat_token),
               context.prove_device_data |> Map.delete(:raw_eat_token)
             )
    end

    test "spots a nonce of incorrect length", context do
      prove_device_msg_wrong =
        prove_device_fixture(
          %{nonce_to2_prove_dv: :crypto.strong_rand_bytes(15)},
          context.device_key
        )

      {:error, :message_body_error} =
        ProveDevice.decode(prove_device_msg_wrong, context.device_key)
    end

    test "spots a GUID of incorrect length", context do
      prove_device_msg_wrong =
        prove_device_fixture(%{guid: :crypto.strong_rand_bytes(15)}, context.device_key)

      {:error, :message_body_error} =
        ProveDevice.decode(prove_device_msg_wrong, context.device_key)
    end

    test "spots missing CBOR Tags", context do
      # encode/sign the message but do not include any CBOR tag
      Mimic.stub(ProveDevice, :encode_sign, fn msg_data, dev_key ->
        encode_sign_missing_cbor_tags(msg_data, dev_key)
      end)

      prove_device_msg_notag =
        context.prove_device_data |> ProveDevice.encode_sign(context.device_key)

      # the first check that fails is the one about the EAT FDO claim decode
      {:error, :message_body_error} =
        ProveDevice.decode(prove_device_msg_notag, context.device_key)
    end
  end

  @tag owner_key: "EC256"
  test "verify ES256 signature success and returns Msg 65", context do
    %{
      realm_name: realm_name,
      session: session,
      device_key: device_key,
      xb: xb,
      owner_key: owner_key
    } = context

    prove_device_msg =
      %ProveDevice{
        xb_key_exchange: xb,
        nonce_to2_prove_dv: session.prove_dv_nonce,
        nonce_to2_setup_dv: @test_setup_dv_nonce,
        guid: session.device_id,
        raw_eat_token: <<>>
      }
      |> ProveDevice.encode_sign(device_key)

    creds = dummy_creds(owner_key)

    assert {:ok, %{setup_dv_nonce: @test_setup_dv_nonce, resp: msg_65_payload}} =
             OwnerOnboarding.verify_and_build_response(
               realm_name,
               session,
               prove_device_msg,
               creds
             )

    assert %CBOR.Tag{tag: 18, value: _} = msg_65_payload

    {:ok, setup_device_msg_decoded} = COSE.Messages.Sign1.decode(msg_65_payload)

    assert setup_device_msg_decoded.phdr.alg == :es256

    # message is signed with the owner EC256 private key and can be verified using the related public key
    assert COSE.Messages.Sign1.verify(setup_device_msg_decoded, owner_key)
  end

  test "verify ES256 fails if Nonce does not match", context do
    %{
      realm_name: realm_name,
      session: session,
      device_key: device_key,
      xb: xb,
      owner_key: owner_key
    } =
      context

    wrong_nonce = :crypto.strong_rand_bytes(16)

    body =
      %ProveDevice{
        xb_key_exchange: xb,
        nonce_to2_prove_dv: wrong_nonce,
        nonce_to2_setup_dv: @test_setup_dv_nonce,
        guid: session.device_id,
        raw_eat_token: <<>>
      }
      |> ProveDevice.encode_sign(device_key)

    creds = dummy_creds(owner_key)

    assert {:error, :invalid_message} =
             OwnerOnboarding.verify_and_build_response(
               realm_name,
               session,
               body,
               creds
             )
  end

  test "verify ES256 fails if Device ID (GUID) does not match", context do
    %{
      realm_name: realm_name,
      session: session,
      device_key: device_key,
      xb: xb,
      owner_key: owner_key
    } =
      context

    body =
      %ProveDevice{
        xb_key_exchange: xb,
        nonce_to2_prove_dv: session.prove_dv_nonce,
        nonce_to2_setup_dv: @test_setup_dv_nonce,
        guid: "wrong_guid",
        raw_eat_token: <<>>
      }
      |> ProveDevice.encode_sign(device_key)

    creds = dummy_creds(owner_key)

    assert {:error, :message_body_error} =
             OwnerOnboarding.verify_and_build_response(
               realm_name,
               session,
               body,
               creds
             )
  end

  test "verify ES256 fails with wrong public key", context do
    %{
      realm_name: realm_name,
      session: session,
      xb: xb,
      owner_key: owner_key
    } =
      context

    device_key2 = COSE.Keys.ECC.generate(:es256)

    body =
      %ProveDevice{
        xb_key_exchange: xb,
        nonce_to2_prove_dv: session.prove_dv_nonce,
        nonce_to2_setup_dv: @test_setup_dv_nonce,
        guid: session.device_id,
        raw_eat_token: <<>>
      }
      |> ProveDevice.encode_sign(device_key2)

    creds = dummy_creds(owner_key)

    assert {:error, :invalid_message} =
             OwnerOnboarding.verify_and_build_response(
               realm_name,
               session,
               body,
               creds
             )
  end

  describe "verify response SetupDevice is correctly signed" do
    setup context do
      %{
        owner_key: owner_key,
        session: session,
        xb: xb,
        device_key: device_key
      } = context

      creds = dummy_creds(owner_key)

      prove_device_msg =
        %ProveDevice{
          xb_key_exchange: xb,
          nonce_to2_prove_dv: session.prove_dv_nonce,
          nonce_to2_setup_dv: @test_setup_dv_nonce,
          guid: session.device_id,
          raw_eat_token: <<>>
        }
        |> ProveDevice.encode_sign(device_key)

      %{
        creds: creds,
        prove_device_msg: prove_device_msg
      }
    end

    @tag owner_key: "EC384"
    test "with EC384 owner key",
         context do
      %{
        realm_name: realm_name,
        session: session,
        creds: creds,
        prove_device_msg: prove_device_msg
      } =
        context

      assert {:ok, %{resp: setup_device_msg}} =
               OwnerOnboarding.verify_and_build_response(
                 realm_name,
                 session,
                 prove_device_msg,
                 creds
               )

      {:ok, setup_device_msg_decoded} = COSE.Messages.Sign1.decode(setup_device_msg)

      assert setup_device_msg_decoded.phdr.alg == :es384

      # message is signed with the EC384 owner private key and can be verified using the related public key
      assert COSE.Messages.Sign1.verify(setup_device_msg_decoded, creds.owner_private_key)
    end

    @tag owner_key: "RSA2048"
    test "with RSA2048 owner key",
         context do
      %{
        realm_name: realm_name,
        session: session,
        creds: creds,
        prove_device_msg: prove_device_msg
      } =
        context

      assert {:ok, %{resp: setup_device_msg}} =
               OwnerOnboarding.verify_and_build_response(
                 realm_name,
                 session,
                 prove_device_msg,
                 creds
               )

      {:ok, setup_device_msg_decoded} = COSE.Messages.Sign1.decode(setup_device_msg)

      assert setup_device_msg_decoded.phdr.alg == :rs256

      # message is signed with the RSA2048 owner private key and can be verified using the related public key
      assert COSE.Messages.Sign1.verify(setup_device_msg_decoded, creds.owner_private_key)
    end

    @tag owner_key: "RSA3072"
    test "with RSA3072 owner key",
         context do
      %{
        realm_name: realm_name,
        session: session,
        creds: creds,
        prove_device_msg: prove_device_msg
      } =
        context

      assert {:ok, %{resp: setup_device_msg}} =
               OwnerOnboarding.verify_and_build_response(
                 realm_name,
                 session,
                 prove_device_msg,
                 creds
               )

      {:ok, setup_device_msg_decoded} = COSE.Messages.Sign1.decode(setup_device_msg)

      assert setup_device_msg_decoded.phdr.alg == :rs384

      # message is signed with the RSA3072 owner private key and can be verified using the related public key
      assert COSE.Messages.Sign1.verify(setup_device_msg_decoded, creds.owner_private_key)
    end
  end

  defp dummy_creds(owner_key) do
    owner_pub_key =
      case owner_key do
        %ECC{} ->
          %PublicKey{
            type: ECC.curve(owner_key),
            encoding: :cosekey,
            body: COSE.Keys.ECC.public_key(owner_key)
          }

        %RSA{} ->
          %PublicKey{
            type: :rsapss,
            encoding: :cosekey,
            body: COSE.Keys.RSA.public_key(owner_key)
          }
      end

    %{
      guid: @test_guid,
      rendezvous_info: sample_rv_info(),
      owner_pub_key: owner_pub_key,
      device_info: "test",
      owner_private_key: owner_key
    }
  end

  defp encode_sign_missing_cbor_tags(msg_data, dev_key) do
    payload_claims = %{
      fdo: [msg_data.xb_key_exchange],
      nonce: msg_data.nonce_to2_prove_dv,
      ueid: EAToken.build_ueid(msg_data.guid)
    }

    uhdr_claims = %{
      euph_nonce: msg_data.nonce_to2_setup_dv
    }

    extra_uhdr_claims = %{ProveDevice.euph_nonce_claim_key() => :euph_nonce}

    EAToken.encode_sign(payload_claims, uhdr_claims, dev_key, extra_uhdr_claims)
  end

  defp prove_device_fixture(overwrite_submap \\ %{}, dev_key) do
    ProveDevice.generate()
    |> Map.merge(overwrite_submap)
    |> ProveDevice.encode_sign(dev_key)
  end
end
