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

defmodule Astarte.FDO.OwnershipVoucher do
  @moduledoc false
  use TypedStruct

  alias Astarte.FDO.Hash
  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.FDO.OwnershipVoucher.Header

  typedstruct do
    field(:protocol_version, :integer)
    field(:header, Header.t())
    field(:hmac, Hash.t())
    field(:cert_chain, [binary()] | nil)
    field(:entries, list())
  end

  def decode_cbor(cbor) do
    case CBOR.decode(cbor) do
      {:ok, message, _} -> decode(message)
      _ -> :error
    end
  end

  def decode(cbor_list) do
    with [protocol, header, cbor_hmac, cert_chain, entries] <- cbor_list,
         %CBOR.Tag{tag: :bytes, value: cbor_header} <- header,
         {:ok, header} <- Header.decode_cbor(cbor_header),
         {:ok, hmac} <- Hash.decode(cbor_hmac),
         {:ok, cert_chain} <- extract_cert_chain(cert_chain) do
      ownership_voucher =
        %OwnershipVoucher{
          protocol_version: protocol,
          header: header,
          hmac: hmac,
          cert_chain: cert_chain,
          entries: entries
        }

      {:ok, ownership_voucher}
    else
      _ -> :error
    end
  end

  defp extract_cert_chain(cert_chain) do
    extracted =
      cert_chain
      |> Enum.map(fn
        %CBOR.Tag{tag: :bytes, value: cert} -> cert
        _ -> :error
      end)

    Enum.find(extracted, {:ok, extracted}, &(&1 == :error))
  end

  def generate_replacement_voucher(ownership_voucher, session) do
    new_header =
      ownership_voucher.header
      |> Map.put(:guid, session.replacement_guid)
      |> Map.put(:rendezvous_info, session.replacement_rv_info)
      |> Map.put(:public_key, session.replacement_pub_key)

    new_voucher =
      ownership_voucher
      |> Map.put(:hmac, session.replacement_hmac)
      |> Map.put(:header, new_header)
      |> Map.put(:entries, [])

    {:ok, new_voucher}
  end

  def encode(voucher) do
    header_binary = Header.cbor_encode(voucher.header)
    hmac_list = Hash.encode(voucher.hmac)

    [
      voucher.protocol_version,
      %CBOR.Tag{tag: :bytes, value: header_binary},
      hmac_list,
      Enum.map(voucher.cert_chain || [], fn cert -> %CBOR.Tag{tag: :bytes, value: cert} end),
      voucher.entries
    ]
  end

  def cbor_encode(voucher) do
    encode(voucher) |> CBOR.encode()
  end

  def credential_reuse?(_session) do
    # Credential reuse requires also Owner2Key and/or rv info
    # to be changed for credential reuse; so far, there is no API to do so,
    # so it is limited to the guid
    true
  end
end
