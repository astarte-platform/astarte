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

defmodule Astarte.FDO.Core.OwnershipVoucher do
  @moduledoc false
  use TypedStruct

  alias Astarte.FDO.Core.Hash
  alias Astarte.FDO.Core.OwnershipVoucher
  alias Astarte.FDO.Core.OwnershipVoucher.Header

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

  @type decoded_voucher :: list()

  @ownership_voucher_regex ~r/-----BEGIN OWNERSHIP VOUCHER-----\n(?<voucher>[\w\+\/\s\=]*)\n-----END OWNERSHIP VOUCHER-----/

  @spec binary_voucher(String.t()) :: {:ok, binary()} | {:error, :invalid_certificate}
  def binary_voucher(ownership_voucher_certificate) do
    case Regex.named_captures(@ownership_voucher_regex, ownership_voucher_certificate) do
      %{"voucher" => voucher} ->
        case Base.decode64(voucher, ignore: :whitespace) do
          {:ok, decoded_voucher} -> {:ok, decoded_voucher}
          :error -> {:error, :invalid_certificate}
        end

      nil ->
        {:error, :invalid_certificate}
    end
  end

  def device_public_key(ownership_voucher) do
    case ownership_voucher.cert_chain do
      nil -> {:ok, nil}
      [device_cert | _] -> parse_device_certificate(device_cert)
      [] -> :error
    end
  end

  def parse_device_certificate(device_cert_bin) do
    with {:ok, cert} <- decode_cert(device_cert_bin),
         {:OTPCertificate, otptbs_certificate, _, _} <- cert,
         {:OTPTBSCertificate, _, _, _, _, _, _, pubkey_info, _, _, _} <- otptbs_certificate,
         {:OTPSubjectPublicKeyInfo, _, pubkey} <- pubkey_info do
      {:ok, pubkey}
    else
      _ -> :error
    end
  end

  defp decode_cert(cert_bin) do
    {:ok, :public_key.pkix_decode_cert(cert_bin, :otp)}
  rescue
    _ -> :error
  end
end
