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

  alias Astarte.Pairing.FDO.OwnerOnboarding.Core, as: OwnerOnboardingCore
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnershipVoucher.Core, as: OwnershipVoucherCore
  alias Astarte.Pairing.FDO.Rendezvous.Core, as: RendezvousCore
  alias Astarte.Pairing.Queries
  alias Astarte.Pairing.Config
  require Logger

  @max_owner_message_size 65_535
  @rsa_public_exponent 65_537
  @cupd_nonce_tag 256
  @cuph_owner_pubkey_tag 257

  def hello_device(realm_name, cbor_hello_device) do
    with {:ok, hello_device} <- OwnerOnboardingCore.decode_hello_device(cbor_hello_device),
         %{device_id: device_id, kex_name: kex_name} = hello_device,
         {:ok, ownership_voucher} <- Queries.get_ownership_voucher(realm_name, device_id),
         {:ok, owner_private_key} <- fetch_owner_private_key(realm_name, device_id),
         {:ok, session} <- Session.new(realm_name, device_id, kex_name, owner_private_key) do
      cbor_ov_header = OwnerOnboardingCore.ov_header(ownership_voucher)
      num_ov_entries = OwnerOnboardingCore.num_ov_entries(ownership_voucher)
      hmac = OwnerOnboardingCore.hmac(ownership_voucher)
      hello_device_hash = OwnerOnboardingCore.compute_hello_device_hash(cbor_hello_device)
      unprotected_headers = build_unprotected_headers(ownership_voucher, session.prove_ov_nonce)

      to2_proveovhdr_payload =
        build_to2_proveovhdr_payload(
          cbor_ov_header,
          num_ov_entries,
          hmac,
          hello_device.nonce,
          nil,
          session.xa,
          hello_device_hash
        )

      message =
        RendezvousCore.build_cose_sign1(
          to2_proveovhdr_payload,
          owner_private_key,
          unprotected_headers
        )

      {:ok, session.key, message}
    else
      {:error, reason} ->
        Logger.error("Failed to process hello_device: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_owner_private_key(realm_name, device_id) do
    with {:ok, pem_key} <- Queries.get_owner_private_key(realm_name, device_id) do
      COSE.Keys.from_pem(pem_key)
    end
  end

  defp build_to2_proveovhdr_payload(
         cbor_ov_header,
         num_ov_entries,
         hmac,
         nonce_hello_device,
         eb_sig_info,
         xa_key_exchange,
         hello_device_hash
       ) do
    [
      cbor_ov_header,
      num_ov_entries,
      hmac,
      nonce_hello_device,
      eb_sig_info,
      xa_key_exchange,
      hello_device_hash,
      @max_owner_message_size
    ]
  end

  defp build_unprotected_headers(ownership_voucher, nonce) do
    %{
      @cupd_nonce_tag => nonce,
      @cuph_owner_pubkey_tag => OwnerOnboardingCore.ov_last_entry_public_key(ownership_voucher)
    }
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

  def prove_device(realm_name, device_pub_key, body) do
    # TODO: nonce and device_id must be read from session
    device_guid = "placeholder"
    session_key = "placeholder"
    nonce = "placeholder"

    {:ok, current_rendezvous_info} =
      RendezvousCore.get_rv_to2_addr_entry("#{realm_name}.#{Config.base_domain!()}")

    {:ok, ownership_voucher} =
      Queries.get_ownership_voucher(realm_name, device_guid)

    connection_credentials = %{
      guid: device_guid,
      rendezvous_info: current_rendezvous_info,
      owner_pub_key: OwnerOnboardingCore.ov_last_entry_public_key(ownership_voucher),
      device_info: "owned by astarte - realm #{realm_name}.#{Config.base_domain!()}"
    }

    with {:ok, setup_device_message} <-
           verify(body, device_pub_key, session_key, nonce, device_guid, connection_credentials) do
      {:ok, setup_device_message}
    else
      _ ->
        {:error, "invalid_signature"}
    end
  end

  def verify(body, device_pub_key, session_key, nonce_to_check, device_id, connection_credentials) do
    with {:ok, [protected_bin, _unprot, payload_bin, signature], _rest} <- CBOR.decode(body),
         {:ok, protected_header_map, _rest} <- CBOR.decode(protected_bin),
         {:ok, alg} <- fetch_alg(protected_header_map),
         {:ok, to_be_signed_bytes} <- build_sig_structure(protected_bin, payload_bin),
         {:ok, eat_claims, _rest} <- CBOR.decode(payload_bin),
         received_nonce <- Map.get(eat_claims, 10),
         received_device_id <- Map.get(eat_claims, 256),
         true <- received_nonce == nonce_to_check,
         true <- received_device_id == device_id,
         true <- verify_signature(alg, device_pub_key, signature, to_be_signed_bytes),
         {:ok, setup_device_message} <-
           build_setup_device_message(session_key, connection_credentials) do
      {:ok, setup_device_message}
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

  def verify_signature(:es256, pub_key, signature, sig_structure) do
    if byte_size(signature) == 64 do
      <<r_bin::binary-size(32), s_bin::binary-size(32)>> = signature

      # ASN.1/DER requires integers for ECDSA-Sig-Value.
      r = :binary.decode_unsigned(r_bin)
      s = :binary.decode_unsigned(s_bin)

      der_sig = der_encode_ecdsa(r, s)

      :crypto.verify(:ecdsa, :sha256, sig_structure, der_sig, pub_key)
    else
      false
    end
  end

  def verify_signature(:edsdsa, pub_key, signature, sig_structure) do
    :crypto.verify(:eddsa, :none, sig_structure, signature, [pub_key, :ed25519])
  end

  def der_encode_ecdsa(r, s) do
    # assuming ECDSA-Sig-Value record is available
    :public_key.der_encode(:"ECDSA-Sig-Value", {:"ECDSA-Sig-Value", r, s})
  end

  def build_setup_device_message(session_key, creds) do
    new_nonce = :crypto.strong_rand_bytes(16)

    ov_header_array = [
      # Protocol Version
      101,
      # GUID
      creds.guid,
      # RV Info
      creds.rendezvous_info,
      # DeviceInfo
      creds.device_info,
      # PubKey
      creds.owner_pub_key,
      # CertChainHash
      nil
    ]

    ov_header_bin = CBOR.encode(ov_header_array)

    ov_header_hmac = :crypto.mac(:hmac, :sha256, session_key, ov_header_bin)

    ov_next_entry = [ov_header_bin, ov_header_hmac]

    payload_data = [new_nonce, ov_next_entry]
    payload_bin = CBOR.encode(payload_data)

    protected_header = %{1 => 5}
    protected_bin = CBOR.encode(protected_header)
    mac_structure = ["MAC0", protected_bin, <<>>, payload_bin]
    to_be_maced = CBOR.encode(mac_structure)
    tag = :crypto.mac(:hmac, :sha256, session_key, to_be_maced)

    cose_mac0 = [protected_bin, %{}, payload_bin, tag]

    {:ok, CBOR.encode(cose_mac0)}
  end
end
