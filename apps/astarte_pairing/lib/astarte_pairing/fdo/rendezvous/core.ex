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

defmodule Astarte.Pairing.FDO.Rendezvous.Core do
  require Logger

  alias Astarte.Pairing.FDO.Cbor.Core, as: CBORCore

  @es256 -7
  @es256_identifier 1
  @cose_sign1_tag 18

  def get_rv_to2_addr_entries(first_entry, second_entry) do
    # TODO: figure out how this function is supposed to work in practice
    rv_entry1 = CBORCore.build_rv_to2_addr_entry(CBORCore.empty_payload(), first_entry, 8080, 3)
    rv_entry2 = CBORCore.build_rv_to2_addr_entry(CBORCore.empty_payload(), second_entry, 8080, 3)
    {:ok, [rv_entry1, rv_entry2]}
  end

  def build_owner_sign_message(decoded_ownership_voucher, owner_key, nonce, addr_entries) do
    with to0d <- CBORCore.build_to0d(decoded_ownership_voucher, 3600, nonce),
         to1d_to0d_hash <- CBORCore.build_to1d_to0d_hash(to0d),
         to1d_rv = CBORCore.build_to1d_rv(addr_entries),
         blob_payload <- CBORCore.build_to1d_blob_payload(to1d_rv, to1d_to0d_hash),
         {:ok, signature} <- build_cose_sign1(blob_payload, owner_key) do
      result = CBOR.encode([CBORCore.add_cbor_tag(to0d), signature])
      {:ok, result}
    else
      error ->
        Logger.error("build_owner_sign_message error: #{inspect(error)}")
        {:error, error}
    end
  end

  def build_cose_sign1(payload, owner_key) do
    protected_header = %{@es256_identifier => @es256}
    protected_header_cbor = CBOR.encode(protected_header)

    sig_structure = ["Signature#{@es256_identifier}", protected_header_cbor, <<>>, payload]
    sig_structure_cbor = CBOR.encode(sig_structure)

    case sign_with_owner_key(sig_structure_cbor, owner_key) do
      {:ok, raw_signature} ->
        cose_sign1_array = [
          CBORCore.add_cbor_tag(protected_header_cbor),
          %{},
          CBORCore.add_cbor_tag(payload),
          CBORCore.add_cbor_tag(raw_signature)
        ]

        cose_sign1 = %CBOR.Tag{tag: @cose_sign1_tag, value: cose_sign1_array}
        {:ok, cose_sign1}

      {:error, _} ->
        {:error, :signing_error}
    end
  end

  defp sign_with_owner_key(data, pem_key) do
    case decode_owner_private_key(pem_key) do
      {:ok, private_key} ->
        signature = :public_key.sign(data, :sha256, private_key)
        {:ok, signature}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_owner_private_key(key) do
    case :public_key.pem_decode(key) do
      [entry] ->
        safe_decode_pem_entry(entry)

      [] ->
        {:error, :invalid_pem}
    end
  end

  defp safe_decode_pem_entry(entry) do
    try do
      {:ok, :public_key.pem_entry_decode(entry)}
    rescue
      e ->
        Logger.warning("pem_entry_decode failed: #{inspect(e)}")
        {:error, :pem_entry_decoding_failed}
    end
  end

  def get_body_nonce(body) do
    case CBOR.decode(body) do
      {:ok, [%CBOR.Tag{tag: :bytes, value: nonce}], _rest}
      when is_binary(nonce) and byte_size(nonce) == 16 ->
        {:ok, nonce}

      {:ok, [%CBOR.Tag{tag: :bytes, value: nonce}], _rest}
      when is_binary(nonce) and byte_size(nonce) != 16 ->
        {:error, :unexpected_nonce_size}

      {:ok, _decoded, _rest} ->
        {:error, :unexpected_body_format}

      {:error, _} ->
        {:error, :cbor_decode_error}
    end
  end
end
