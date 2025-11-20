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
  @http 3
  @load_balancer_port 4003

  def get_rv_to2_addr_entry(full_dns_name, pre_existing_entries \\ []) do
    rv_entry = CBORCore.build_rv_to2_addr_entry(nil, full_dns_name, @load_balancer_port, @http)
    {:ok, [rv_entry] ++ pre_existing_entries}
  end

  def build_owner_sign_message(decoded_ownership_voucher, owner_key, nonce, addr_entries) do
    to0d = CBORCore.build_to0d(decoded_ownership_voucher, 3600, nonce)
    to1d_to0d_hash = CBORCore.build_to1d_to0d_hash(to0d)
    to1d_rv = CBORCore.build_to1d_rv(addr_entries)
    blob_payload = CBORCore.build_to1d_blob_payload(to1d_rv, to1d_to0d_hash)
    signature = build_cose_sign1(blob_payload, owner_key)

    CBOR.encode([CBORCore.add_cbor_tag(to0d), signature])
  end

  def build_cose_sign1(payload, owner_key, unprotected_header \\ %{}) do
    protected_header = %{@es256_identifier => @es256}
    protected_header_cbor = CBOR.encode(protected_header)

    sig_structure = ["Signature#{@es256_identifier}", protected_header_cbor, <<>>, payload]
    sig_structure_cbor = CBOR.encode(sig_structure)

    raw_signature = :public_key.sign(sig_structure_cbor, :sha256, owner_key)

    cose_sign1_array = [
      CBORCore.add_cbor_tag(protected_header_cbor),
      unprotected_header,
      CBORCore.add_cbor_tag(payload),
      CBORCore.add_cbor_tag(raw_signature)
    ]

    %CBOR.Tag{tag: @cose_sign1_tag, value: cose_sign1_array}
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
