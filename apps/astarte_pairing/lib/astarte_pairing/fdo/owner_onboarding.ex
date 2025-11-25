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
end
