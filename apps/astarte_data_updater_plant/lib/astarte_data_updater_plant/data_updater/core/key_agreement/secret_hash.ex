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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SecretHash do
  @moduledoc """
  Represents the SecretHash (type 2) key-agreement message published on the
  `<realm>/<device>/control/keyAgreement/2` MQTT control topic.

  Can be sent by any of the two parties to verify if the counterpart
  shares the same derived secret key.

  ## Message structure:

      [
        seq_num  :: uint,   # sequence number incremented per MQTT session
        key_hash :: #bstr   # CBOR-encoded bytes containing SHA256 hash of the key
      ]
  """

  use TypedStruct

  alias __MODULE__, as: SecretHash

  typedstruct enforce: true do
    @typedoc "SecretHash key-agreement verification message."
    field :seq_num, non_neg_integer()
    field :key_hash, binary()
  end

  @doc """
  Builds a new `%SecretHash{}` given a sequence number and the shared secret.
  The shared secret is hashed using SHA256.
  """
  @spec new(non_neg_integer(), binary()) :: t()
  def new(seq_num, shared_secret) when is_integer(seq_num) and is_binary(shared_secret) do
    hash = :crypto.hash(:sha256, shared_secret)
    %SecretHash{seq_num: seq_num, key_hash: hash}
  end

  @doc """
  Returns the list representation of a `%SecretHash{}` ready for CBOR encoding.
  """
  @spec encode(t()) :: list()
  def encode(%SecretHash{} = msg) do
    [
      msg.seq_num,
      %CBOR.Tag{tag: :bytes, value: msg.key_hash}
    ]
  end

  @doc """
  CBOR-encodes a `%SecretHash{}` for transmission.
  """
  @spec cbor_encode(t()) :: binary()
  def cbor_encode(%SecretHash{} = msg), do: encode(msg) |> CBOR.encode()

  @doc """
  Decodes and validates a raw CBOR payload received on the `control/keyAgreement/2` topic.
  """
  @spec cbor_decode(binary()) :: {:ok, t()} | {:error, atom()}
  def cbor_decode(payload) when is_binary(payload) do
    case CBOR.decode(payload) do
      {:ok, raw, _rest} -> decode(raw)
      {:error, _reason} -> {:error, :invalid_payload}
    end
  end

  defp decode([seq_num, key_hash_tag]) when is_integer(seq_num) and seq_num >= 0 do
    with {:ok, key_hash} <- unwrap_bytes(key_hash_tag),
         :ok <- validate_hash_length(key_hash) do
      {:ok, %SecretHash{seq_num: seq_num, key_hash: key_hash}}
    end
  end

  defp decode(_), do: {:error, :invalid_payload}

  defp unwrap_bytes(%CBOR.Tag{tag: :bytes, value: value}), do: {:ok, value}
  defp unwrap_bytes(_), do: {:error, :invalid_payload}

  # SHA256 output is exactly 32 bytes
  defp validate_hash_length(hash) when byte_size(hash) == 32, do: :ok
  defp validate_hash_length(_), do: {:error, :invalid_hash_length}

  @doc """
  Verifies if the received SecretHash matches the expected derived shared secret
  using a constant-time comparison to prevent timing attacks.
  """
  @spec verify(t(), binary()) :: :ok | {:error, :hash_mismatch}
  def verify(%SecretHash{key_hash: received_hash}, shared_secret) do
    expected_hash = :crypto.hash(:sha256, shared_secret)

    if :crypto.hash_equals(expected_hash, received_hash) do
      :ok
    else
      {:error, :hash_mismatch}
    end
  end
end
