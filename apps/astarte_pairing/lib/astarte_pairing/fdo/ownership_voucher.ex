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
  alias Astarte.Pairing.Queries
  require Logger

  @one_week 604_800
  def save_voucher(realm_name, voucher_blob, private_key) do
    with {:ok, device_guuid} <- extract_device_guuid_from_voucher_data(voucher_blob),
         {:ok, _} <- validate_private_key(private_key),
         {:ok, _} <-
           Queries.create_ownership_voucher(
             realm_name,
             device_guuid,
             voucher_blob,
             private_key,
             @one_week
           ) do
      :ok
    end
  end

  defp extract_device_guuid_from_voucher_data(voucher_blob) do
    with {:ok, cbor_data} <- clean_and_b64_decode_voucher_blob(voucher_blob),
         {:ok, decoded_voucher, _rest} <- CBOR.decode(cbor_data),
         {:ok, decoded_header, _rest} <- extract_and_decode_voucher_header(decoded_voucher) do
      device_guid_binary = device_id_from_header(decoded_header)
      {:ok, UUID.binary_to_string!(device_guid_binary)}
    else
      error ->
        "error extracting device guid from ownership voucher: #{inspect(error)}"
        |> Logger.error()

        {:error, error}
    end
  end

  defp clean_and_b64_decode_voucher_blob(voucher_blob) do
    ov_data =
      voucher_blob
      |> String.replace("-----BEGIN OWNERSHIP VOUCHER-----", "")
      |> String.replace("-----END OWNERSHIP VOUCHER-----", "")
      |> String.replace(~r/\s/, "")

    Base.decode64(ov_data)
  end

  defp extract_and_decode_voucher_header(decoded_voucher) do
    decoded_voucher |> Enum.at(1) |> Map.fetch!(:value) |> CBOR.decode()
  end

  defp device_id_from_header(decoded_header) do
    decoded_header
    |> Enum.at(1)
    |> Map.fetch!(:value)
  end

  defp validate_private_key(private_key) do
    # FIXME: private key controls are demanded to another PR
    {:ok, private_key}
  end
end
