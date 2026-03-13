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
    |> Core.entry_private_key()
  end

  def get_ov_entry(%OwnershipVoucher{entries: entries}, entry_num) do
    case Enum.fetch(entries, entry_num) do
      {:ok, entry} ->
        {:ok, CBOR.encode([entry_num, entry])}

      :error ->
        {:error, :invalid_message}
    end
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

  def credential_reuse?(_session) do
    # Credential reuse requires also Owner2Key and/or rv info
    # to be changed for credential reuse; so far, there is no API to do so,
    # so it is limited to the guid
    true
  end
end
