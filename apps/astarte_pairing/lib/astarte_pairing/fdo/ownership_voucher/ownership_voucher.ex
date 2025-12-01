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

defmodule Astarte.Pairing.FDO.OwnershipVoucher do
  use TypedStruct

  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnershipVoucher.Core
  alias Astarte.Pairing.FDO.OwnershipVoucher.Header
  alias Astarte.Pairing.FDO.Types.Hash
  alias Astarte.Pairing.Queries

  require Logger

  typedstruct do
    field :protocol_version, :integer
    field :header, Header.t()
    field :hmac, Hash.t()
    field :cert_chain, [binary()] | nil
    field :entries, list()

    field :cbor_header, binary()
    field :cbor_hmac, binary()
  end

  @one_week 604_800

  def save_voucher(realm_name, cbor_ownership_voucher, device_guid, owner_private_key) do
    with {:ok, _} <-
           Queries.create_ownership_voucher(
             realm_name,
             device_guid,
             cbor_ownership_voucher,
             owner_private_key,
             @one_week
           ) do
      :ok
    end
  end

  def owner_public_key(ownership_voucher) do
    # TODO: handle ownership vouchers without entries
    List.last(ownership_voucher.entries)
    |> Core.entry_private_key()
  end

  def device_public_key(ownership_voucher) do
    # The FIDO Device Onboard public key is in the leaf certificate (the "end-entity" key),
    # which is the first element of the x5chain sequence
    case ownership_voucher.cert_chain do
      nil -> {:ok, nil}
      [device_cert | _] -> Core.parse_device_certificate(device_cert)
      [] -> :error
    end
  end

  def fetch(realm_name, device_id) do
    case Queries.get_ownership_voucher(realm_name, device_id) do
      {:ok, ownership_voucher_cbor} -> decode_cbor(ownership_voucher_cbor)
      _ -> :error
    end
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
          entries: entries,
          cbor_header: cbor_header,
          cbor_hmac: cbor_hmac
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

  def generate_replacement_voucher(_ownership_voucher, nil) do
    # If ReplacementHMac is null, we don't create a new voucher (Credential Reuse)
    {:ok, nil}
  end

  def generate_replacement_voucher(ownership_voucher, new_dev_id_hmac) do
    new_voucher = ownership_voucher |> Map.put(:hmac, new_dev_id_hmac) |> Map.put(:entries, [])
    {:ok, new_voucher}
  end
end
