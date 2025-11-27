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

defmodule Astarte.Pairing.FDO.OwnerOnboarding do
  @moduledoc """
  This module implements the logic for processing FDO (FIDO Device Onboarding) owner onboarding requests,
  including decoding device hello messages, retrieving ownership vouchers, and building signed responses.
  It manages cryptographic operations such as HMAC and COSE_Sign1 signing,
  and supports key exchange parameter generation for secure device onboarding.
  """

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceAttestation
  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.ProveOVHdr
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnerOnboarding.Done, as: DonePayload
  alias Astarte.Pairing.FDO.OwnerOnboarding.Done2, as: Done2Payload
  alias Astarte.Pairing.FDO.OwnershipVoucher.Core, as: OwnershipVoucherCore
  alias Astarte.Pairing.FDO.Rendezvous.RvTO2Addr
  alias Astarte.Pairing.FDO.Types.Hash
  alias Astarte.Pairing.Queries
  alias COSE.Messages.Sign1

  require Logger

  @max_owner_message_size 65_535
  @rsa_public_exponent 65_537

  def hello_device(realm_name, cbor_hello_device) do
    with {:ok, hello_device} <- HelloDevice.decode(cbor_hello_device),
         device_id = hello_device.device_id,
         {:ok, ownership_voucher} <- OwnershipVoucher.fetch(realm_name, device_id),
         {:ok, owner_private_key} <- fetch_owner_private_key(realm_name, device_id),
         {:ok, pub_key} <- OwnershipVoucher.owner_public_key(ownership_voucher),
         {:ok, session} <-
           Session.new(realm_name, hello_device, ownership_voucher, owner_private_key) do
      num_ov_entries = Enum.count(ownership_voucher.entries)
      hello_device_hash = Hash.new(:sha256, cbor_hello_device)
      eb_sig_info = DeviceAttestation.eb_sig_info(session.device_signature)

      prove_ovh =
        %ProveOVHdr{
          cbor_ov_header: ownership_voucher.cbor_header,
          cbor_hmac: ownership_voucher.cbor_hmac,
          num_ov_entries: num_ov_entries,
          nonce_to2_prove_ov: hello_device.nonce,
          eb_sig_info: eb_sig_info,
          xa_key_exchange: session.xa,
          hello_device_hash: hello_device_hash,
          max_owner_message_size: @max_owner_message_size
        }

      message =
        ProveOVHdr.encode_sign(prove_ovh, session.prove_dv_nonce, pub_key, owner_private_key)

      {:ok, session.key, message}
    else
      error ->
        Logger.error("Failed to process hello_device: #{inspect(error)}")
        error
    end
  end

  defp fetch_owner_private_key(realm_name, device_id) do
    with {:ok, pem_key} <- Queries.get_owner_private_key(realm_name, device_id) do
      COSE.Keys.from_pem(pem_key)
    end
  end

  def generate_rsa_2048_key() do
    options = {:rsa, 2048, @rsa_public_exponent}

    :public_key.generate_key(options)
  end

  def get_public_key(private_key_record) do
    case private_key_record do
      {:RSAPrivateKey, _, modulus, public_exponent, _, _, _, _, _, _, _} ->
        public_key_record = {:RSAPublicKey, modulus, public_exponent}
        {:ok, public_key_record}

      _ ->
        {:error, :invalid_private_key_format}
    end
  end

  def ov_next_entry(cbor_body, realm_name, device_id) do
    # entry num represent the current enties we need to check for in the ov
    with {:ok, [entry_num], _} <- CBOR.decode(cbor_body),
         {:ok, ownership_voucher} <- Queries.get_ownership_voucher(realm_name, device_id) do
      OwnershipVoucherCore.get_ov_entry(ownership_voucher, entry_num)
    end
  end

  def prove_device(realm_name, body, session) do
    device_guid = session.device_id
    nonce = session.nonce
    device_pub_key = session.device_public_key

    current_rendezvous_info = RvTO2Addr.for_realm(realm_name)

    {:ok, ownership_voucher} =
      OwnershipVoucher.fetch(realm_name, device_guid)

    {:ok, private_key} =
      Queries.get_owner_private_key(realm_name, device_guid)

    {:ok, private_key} = COSE.Keys.from_pem(private_key)

    connection_credentials = %{
      guid: device_guid,
      rendezvous_info: current_rendezvous_info,
      owner_pub_key: OwnershipVoucher.owner_public_key(ownership_voucher),
      owner_private_key: private_key,
      device_info: "owned by astarte - realm #{realm_name}.#{Config.base_url_domain!()}"
    }

    with {:ok, setup_device_message} <-
           verify(body, device_pub_key, nonce, device_guid, connection_credentials) do
      {:ok, setup_device_message}
    else
      _ ->
        {:error, "invalid_signature"}
    end
  end

  def verify(body, device_pub_key, nonce_to_check, device_id, connection_credentials) do
    with {:ok, sign1} <- Sign1.verify_decode(body, device_pub_key),
         {:ok, eat_claims, _rest} <- CBOR.decode(sign1.payload),
         received_nonce <- Map.get(eat_claims, 10),
         received_device_id <- Map.get(eat_claims, 256),
         true <- received_nonce == nonce_to_check,
         true <- received_device_id == device_id do
      build_setup_device_message(connection_credentials, nonce_to_check)
    else
      _ ->
        {:error, :invalid_signature}
    end
  end

  def fetch_alg(header_map) when is_map(header_map) do
    case Map.get(header_map, 1) do
      -7 -> {:ok, :es256}
      -8 -> {:ok, :edsdsa}
      _ -> {:error, :unsupported_alg}
    end
  end

  def fetch_alg(binary) when is_binary(binary) do
    with {:ok, map, _rest} <- CBOR.decode(binary), do: fetch_alg(map)
  end

  def build_sig_structure(protected_bin, payload_bin) do
    sig_struct = [
      "Signature1",
      protected_bin,
      # external_aad empty in FDO
      <<>>,
      payload_bin
    ]

    {:ok, CBOR.encode(sig_struct)}
  end

  def der_encode_ecdsa(r, s) do
    # assuming ECDSA-Sig-Value record is available
    :public_key.der_encode(:"ECDSA-Sig-Value", {:"ECDSA-Sig-Value", r, s})
  end

  def build_setup_device_message(creds, nonce) do
    payload_array = [
      creds.rendezvous_info,
      creds.guid,
      nonce,
      creds.owner_pub_key
    ]

    protected_header_map = %{alg: :es256}

    res =
      payload_array
      |> CBOR.encode()
      |> Sign1.build(protected_header_map)
      |> Sign1.sign_encode_cbor(creds.owner_private_key)

    {:ok, res}
  end

  def done(to2_session, cbor_body) do
    # retrieve nonce NonceTO2ProveDv from session and check against incoming nonce from device
    # if match -> retrieve NonceTO2SetupDv from session and send back to device
    with {:ok, %DonePayload{nonce_to2_prove_dv: prove_dv_nonce_challenge}} <-
           DonePayload.decode(cbor_body),
         :ok <-
           check_prove_dv_nonces_equality(prove_dv_nonce_challenge, to2_session.prove_dv_nonce) do
      done2_message = build_done2_message(to2_session.setup_dv_nonce)
      {:ok, done2_message}
    end
  end

  defp check_prove_dv_nonces_equality(incoming_nonce, stored_nonce) do
    case incoming_nonce == stored_nonce do
      true ->
        :ok

      false ->
        # non-matching proveDv nonces
        # TODO build error msg 101 ??
        {:error, :prove_dv_nonce_mismatch}
    end
  end

  defp build_done2_message(setup_dv_nonce) do
    %Done2Payload{:nonce_to2_setup_dv => setup_dv_nonce} |> Done2Payload.encode()
  end
end
