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
  @moduledoc """
  This module provides functions to manage ownership vouchers, including saving them to the database,
  fetching them, and generating replacement vouchers.
  """

  alias Astarte.DataAccess.FDO.Queries
  alias Astarte.FDO.Core.OwnershipVoucher
  alias Astarte.FDO.Core.OwnershipVoucher.Core

  def save_voucher(realm_name, attrs) do
    with {:ok, _} <- Queries.create_ownership_voucher(realm_name, attrs) do
      :ok
    end
  end

  def fetch(realm_name, guid) do
    case Queries.get_ownership_voucher(realm_name, guid) do
      {:ok, ownership_voucher_cbor} ->
        OwnershipVoucher.decode_cbor(ownership_voucher_cbor)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def owner_public_key(ownership_voucher) do
    # N.B.: Checking if there are entries is not necessary,
    # as by spec the ownership voucher will always have at least one entry
    List.last(ownership_voucher.entries)
    |> Core.entry_public_key()
  end

  def get_ov_entry(%OwnershipVoucher{entries: entries}, entry_num) do
    case Enum.fetch(entries, entry_num) do
      {:ok, entry} ->
        {:ok, CBOR.encode([entry_num, entry])}

      :error ->
        {:error, :invalid_message}
    end
  end

  def generate_replacement_voucher(ownership_voucher, ov_entry, session) do
    guid = ov_entry.replacement_guid || ownership_voucher.header.guid

    rendezvous_info =
      ov_entry.replacement_rendezvous_info || ownership_voucher.header.rendezvous_info

    public_key = ov_entry.replacement_public_key || ownership_voucher.header.public_key

    new_header =
      ownership_voucher.header
      |> Map.put(:guid, guid)
      |> Map.put(:rendezvous_info, rendezvous_info)
      |> Map.put(:public_key, public_key)

    new_voucher =
      ownership_voucher
      |> Map.put(:hmac, session.replacement_hmac)
      |> Map.put(:header, new_header)
      |> Map.put(:entries, [])

    {:ok, new_voucher}
  end

  def credential_reuse?(ov_entry) do
    is_nil(ov_entry.replacement_public_key) and
      is_nil(ov_entry.replacement_rendezvous_info) and
      is_nil(ov_entry.replacement_guid)
  end

  @doc """
  Decodes a PEM-encoded ownership voucher into a `CoreOwnershipVoucher` struct.
  """
  @spec decode_binary_voucher(String.t()) :: {:ok, OwnershipVoucher.t()} | {:error, atom()}
  def decode_binary_voucher(pem) do
    with {:ok, binary} <- OwnershipVoucher.binary_voucher(pem) do
      OwnershipVoucher.decode_cbor(binary)
    end
  end

  @doc """
  Returns the list of key algorithm atoms compatible with the given ownership voucher.
  Returns an empty list if the key type is unsupported.
  """
  @spec key_algorithm(OwnershipVoucher.t()) :: [atom()]
  def key_algorithm(voucher) do
    {:ok, algorithms} = OwnershipVoucher.key_algorithm_from_type(voucher.header.public_key.type)
    algorithms
  end
end
