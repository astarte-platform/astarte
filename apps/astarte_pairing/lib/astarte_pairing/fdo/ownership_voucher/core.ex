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

defmodule Astarte.Pairing.FDO.OwnershipVoucher.Core do
  alias Astarte.Pairing.FDO.OwnershipVoucher.Core

  @type decoded_voucher :: list()

  @ownership_voucher_regex ~r/-----BEGIN OWNERSHIP VOUCHER-----\n(?<voucher>[\w\+\/\s\=]*)\n-----END OWNERSHIP VOUCHER-----/

  @doc """
    Returns the decoded ownership voucher from a given ownership voucher certificate
  """
  @spec decode_ownership_voucher(String.t()) :: {:ok, decoded_voucher()} | {:error, atom()}
  def decode_ownership_voucher(ownership_voucher_certificate) do
    with {:ok, decoded_base64} <- Core.binary_voucher(ownership_voucher_certificate),
         {:ok, decoded_voucher, _rest} <- CBOR.decode(decoded_base64) do
      {:ok, decoded_voucher}
    end
  end

  @doc """
    Returns the cbor encoded ownership voucher from a given ownership voucher certificate
  """
  @spec binary_voucher(String.t()) :: {:ok, binary()} | {:error, :invalid_certificate}
  def binary_voucher(ownership_voucher_certificate) do
    case Regex.named_captures(@ownership_voucher_regex, ownership_voucher_certificate) do
      %{"voucher" => voucher} -> decode_certificate(voucher)
      nil -> {:error, :invalid_certificate}
    end
  end

  @doc """
    Returns the device guid from an ownership voucher decoded using `decode_ownership_voucher/1`
  """
  @spec device_guid(decoded_voucher()) :: {:ok, binary()} | :error
  def device_guid(decoded_voucher) do
    with {:ok, header_tag} <- header_tag(decoded_voucher) do
      device_id_from_header(header_tag)
    end
  end

  defp header_tag(decoded_voucher) do
    with [_protocol_version, header_tag, _header_hmac, _dev_cert_chain, _entry_array] <-
           decoded_voucher,
         %CBOR.Tag{tag: :bytes, value: header_tag_value} <- header_tag,
         {:ok, decoded_header, _rest} <- CBOR.decode(header_tag_value) do
      {:ok, decoded_header}
    else
      _ -> :error
    end
  end

  defp device_id_from_header(header_tag) do
    with [_protocol_version, guid_tag, _rv_info, _device_info, _pub_key, _dev_cert_chain_hash] <-
           header_tag,
         %CBOR.Tag{tag: :bytes, value: guid} <- guid_tag do
      {:ok, guid}
    else
      _ -> :error
    end
  end

  @spec decode_certificate(String.t()) :: {:ok, binary()} | {:error, :invalid_certificate}
  defp decode_certificate(voucher) do
    case Base.decode64(voucher, ignore: :whitespace) do
      {:ok, decoded_voucher} -> {:ok, decoded_voucher}
      :error -> {:error, :invalid_certificate}
    end
  end
end
