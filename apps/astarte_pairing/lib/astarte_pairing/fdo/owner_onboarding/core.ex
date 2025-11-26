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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.Core do
  @sha256 -16
  # @sha384 -43
  # @hmac_sha256 5
  # @hmac_sha384 6

  def ov_header(ownership_voucher) do
    %CBOR.Tag{tag: _tag, value: cbor_ov_header} = Enum.at(ownership_voucher, 1)
    cbor_ov_header
  end

  def compute_hello_device_hash(cbor_hello_device) do
    hash = :crypto.hash(:sha256, cbor_hello_device)
    [@sha256, hash]
  end

  def hmac(ownership_voucher) do
    [_, _, hmac, _, _] = ownership_voucher
    hmac
  end

  def num_ov_entries(ownership_voucher) do
    ownership_voucher
    |> ov_entries()
    |> length()
  end

  defp ov_entries([_version, _tag, _hmac, _cert_chain, entries]), do: entries

  def ov_last_entry_public_key(ownership_voucher) do
    ownership_voucher
    |> leaf_ov_entry()
    |> extract_entry_public_key()
    |> decode_public_key()
  end

  defp extract_entry_public_key(%CBOR.Tag{
         tag: 18,
         value: [
           _protected,
           _unprotected,
           %CBOR.Tag{value: public_key},
           _signature
         ]
       }) do
    public_key
  end

  defp decode_public_key(cbor_public_key) do
    {:ok, [_, _, _, [_, _, %CBOR.Tag{tag: _, value: public_key}]], ""} =
      CBOR.decode(cbor_public_key)

    public_key
  end

  defp leaf_ov_entry(ownership_voucher) do
    ownership_voucher
    |> ov_entries()
    |> List.last()
  end

  def counter_mode_kdf(mac_type, mac_subtype, n, secret, context, l) do
    do_counter_mode_kdf(mac_type, mac_subtype, n, secret, context, l, <<>>)
  end

  defp do_counter_mode_kdf(_mac_type, _mac_subtype, 0, _secret, _context, _l, acc), do: acc

  defp do_counter_mode_kdf(mac_type, mac_subtype, n, secret, context, l, acc) do
    data = <<n::integer-unsigned-size(8), "FIDO-KDF"::binary, 0, context::binary, l::binary>>
    new_key = :crypto.mac(mac_type, mac_subtype, secret, data)
    acc = new_key <> acc

    do_counter_mode_kdf(mac_type, mac_subtype, n - 1, secret, context, l, acc)
  end
end
