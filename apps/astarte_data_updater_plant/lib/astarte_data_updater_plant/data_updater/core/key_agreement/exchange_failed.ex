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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeFailed do
  @moduledoc """
  Represents the ExchangeFailed (type 4) key-agreement message published on the
  `<realm>/<device>/control/keyAgreement/4` MQTT control topic.

  Sent by either party to signal that the key exchange has failed.

  ## Message structure:

      [
        reason :: uint   # integer code representing the failure reason
      ]
  """

  use TypedStruct

  alias __MODULE__, as: ExchangeFailed

  # Ecto.Enum parameterized type for error codes.
  @reasons Ecto.ParameterizedType.init(Ecto.Enum,
             values: [
               unspecified: 0,
               hash_mismatch: 1,
               invalid_payload: 2,
               key_derivation_failed: 3,
               seq_num_mismatch: 4
             ]
           )

  @type reason ::
          :unspecified
          | :hash_mismatch
          | :invalid_payload
          | :key_derivation_failed
          | :seq_num_mismatch

  typedstruct enforce: true do
    @typedoc "ExchangeFailed notification message."
    field :reason, reason()
  end

  @doc """
  Builds a new `%ExchangeFailed{}` from a known reason atom.
  """
  @spec new(reason()) :: t()
  def new(reason) do
    case Ecto.Type.cast(@reasons, reason) do
      {:ok, valid_reason} -> %ExchangeFailed{reason: valid_reason}
      _error -> raise ArgumentError, "invalid ExchangeFailed reason: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the list representation of an `%ExchangeFailed{}` ready for CBOR encoding.
  """
  @spec encode(t()) :: list()
  def encode(%ExchangeFailed{reason: reason}) do
    {:ok, code} = Ecto.Type.dump(@reasons, reason)
    [code]
  end

  @doc """
  CBOR-encodes an `%ExchangeFailed{}` for transmission.
  """
  @spec cbor_encode(t()) :: binary()
  def cbor_encode(%ExchangeFailed{} = msg), do: msg |> encode() |> CBOR.encode()

  @doc """
  Decodes and validates a raw CBOR payload received on the `control/keyAgreement/4` topic.
  """
  @spec cbor_decode(binary()) :: {:ok, t()} | {:error, :invalid_payload}
  def cbor_decode(payload) when is_binary(payload) do
    case CBOR.decode(payload) do
      {:ok, raw, _rest} -> decode(raw)
      {:error, _reason} -> {:error, :invalid_payload}
    end
  end

  defp decode([code]) when is_integer(code) and code >= 0 do
    case Ecto.Type.cast(@reasons, code) do
      {:ok, valid_reason} -> {:ok, %ExchangeFailed{reason: valid_reason}}
      _error -> {:error, :invalid_payload}
    end
  end

  defp decode(_), do: {:error, :invalid_payload}
end
