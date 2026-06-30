#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeResp do
  @moduledoc """
  Represents the ExchangeResp (type 1) key-agreement message published by
  Astarte on the `<realm>/<device>/control/keyAgreement/1` MQTT control topic.

  Sent in response to an `InitExchange` message, it carries the sender's
  (Astarte's) ephemeral public key so both sides can independently derive the
  shared secret via ECDH + HKDF.

  ## Message structure:

      [
        seq_num  :: uint,   # sequence number from the corresponding InitExchange
        cose_key :: #bstr   # CBOR-encoded COSE_Key (sender's EC public key)
      ]

  """

  use TypedStruct

  alias __MODULE__, as: ExchangeResp
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange
  alias COSE.Keys.ECC
  alias COSE.Keys.Key
  alias COSE.Keys.OKP

  typedstruct enforce: true do
    @typedoc "ExchangeResp key-agreement message."

    field :seq_num, non_neg_integer()
    field :public_key, Key.t()
  end

  @doc """
  Builds a new `%ExchangeResp{}` from a received `%InitExchange{}`.

  Generates a fresh ephemeral key pair using the same suite (`key_type`) that the remote side
  declared.  The private component of the generated key is retained in
  `public_key` for the subsequent ECDH derivation step.
  """
  @spec new(InitExchange.t()) :: t()
  def new(init_exchange) do
    %InitExchange{seq_num: seq_num, key_type: key_type} = init_exchange
    key = generate_key(key_type)

    %ExchangeResp{seq_num: seq_num, public_key: key}
  end

  defp generate_key(:ecdh_x25519_hkdf_sha256_aes_256_gcm), do: OKP.generate(:enc)
  defp generate_key(:ecdh_p256_hkdf_sha256_aes_256_gcm), do: ECC.generate(:es256)

  @doc """
  Returns the list representation of an `%ExchangeResp{}` ready for CBOR
  encoding.
  """
  @spec encode(t()) :: list()
  def encode(%ExchangeResp{} = msg) do
    cose_key_bytes = COSE.Keys.encode_cbor(msg.public_key)

    [
      msg.seq_num,
      %CBOR.Tag{tag: :bytes, value: cose_key_bytes}
    ]
  end

  @doc """
  CBOR-encodes an `%ExchangeResp{}` for transmission to the device.

  Returns the raw binary ready to be published on the
  `control/keyAgreement/1` MQTT control topic.
  """
  @spec cbor_encode(t()) :: binary()
  def cbor_encode(%ExchangeResp{} = msg), do: encode(msg) |> CBOR.encode()

  @doc """
  Decodes and validates a raw CBOR payload received on the
  `control/keyAgreement/1` topic.
  Requires the expected key_type from the corresponding InitExchange to validate compatibility.
  """
  @spec cbor_decode(binary(), atom()) :: {:ok, t()} | {:error, atom()}
  def cbor_decode(payload, expected_key_type) when is_binary(payload) do
    case CBOR.decode(payload) do
      {:ok, raw, _rest} -> decode(raw, expected_key_type)
      {:error, _reason} -> {:error, :invalid_payload}
    end
  end

  defp decode([seq_num, public_key], expected_key_type)
       when is_integer(seq_num) and seq_num >= 0 do
    with {:ok, cose_key_bytes} <- unwrap_bytes(public_key),
         {:ok, cose_key_map} <- decode_cbor(cose_key_bytes),
         {:ok, cose_key} <- decode_cose_key(cose_key_map, expected_key_type) do
      {:ok, %ExchangeResp{seq_num: seq_num, public_key: cose_key}}
    end
  end

  defp decode(_, _expected_key_type), do: {:error, :invalid_payload}

  # Validate the key against the algorithm specified in InitExchange
  defp decode_cose_key(cose_key_map, expected_key_type) do
    case COSE.Keys.decode(cose_key_map) do
      {:ok, %OKP{crv: :x25519} = key}
      when expected_key_type == :ecdh_x25519_hkdf_sha256_aes_256_gcm ->
        {:ok, key}

      {:ok, %ECC{crv: :p256} = key}
      when expected_key_type == :ecdh_p256_hkdf_sha256_aes_256_gcm ->
        {:ok, key}

      {:ok, _} ->
        {:error, :key_type_mismatch}
    end
  end

  defp unwrap_bytes(%CBOR.Tag{tag: :bytes, value: value}), do: {:ok, value}
  defp unwrap_bytes(_), do: {:error, :invalid_payload}

  defp decode_cbor(bytes) do
    case CBOR.decode(bytes) do
      {:ok, decoded, _rest} -> {:ok, decoded}
      {:error, _reason} -> {:error, :invalid_payload}
    end
  end
end
