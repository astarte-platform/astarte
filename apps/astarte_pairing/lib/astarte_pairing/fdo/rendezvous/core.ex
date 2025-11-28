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

  alias Astarte.Pairing.FDO.Rendezvous.OwnerSign
  alias Astarte.Pairing.FDO.Rendezvous.OwnerSign.TO0D
  alias Astarte.Pairing.FDO.Rendezvous.OwnerSign.TO1D

  def build_owner_sign_message(
        decoded_ownership_voucher,
        owner_key,
        nonce,
        addr_entries,
        wait_seconds
      ) do
    to0d = %TO0D{
      cbor_decoded_ownership_voucher: decoded_ownership_voucher,
      wait_seconds: wait_seconds,
      nonce_to0_sign: nonce
    }

    to1d = %TO1D{rv_to2_addr: addr_entries}
    owner_sign = %OwnerSign{to0d: to0d, to1d: to1d}
    OwnerSign.encode_sign_cbor_with_hash(owner_sign, owner_key)
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
