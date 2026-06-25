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
        seq_num   :: uint,  # sequence number of the message that caused the error
        error_code :: uint,  # integer code representing the failure reason
        error_msg  :: tstr   # additional context
      ]

  ## Error codes:

    * `0` – `internal_server_error`: unexpected server-side failure (e.g. Astarte crash)
    * `1` – `invalid_argument`: wrong payload from the device (e.g. invalid key)
    * `2` – `hash_mismatch`: hash comparison failed
    * `3` – `unprocessable_entity`: structurally valid message that cannot be processed
      (e.g. unsupported algorithm, key-type mismatch)
  """

  use TypedStruct

  alias __MODULE__, as: ExchangeFailed

  # Ecto.Enum parameterized type for error codes.
  @reasons Ecto.ParameterizedType.init(Ecto.Enum,
             values: [
               internal_server_error: 0,
               invalid_argument: 1,
               hash_mismatch: 2,
               unprocessable_entity: 3
             ]
           )

  @type reason ::
          :internal_server_error
          | :invalid_argument
          | :hash_mismatch
          | :unprocessable_entity

  typedstruct enforce: true do
    @typedoc "ExchangeFailed notification message."
    field :seq_num, non_neg_integer()
    field :reason, reason()
    field :error_msg, String.t()
  end

  @doc """
  Builds a new `%ExchangeFailed{}` from a sequence number, reason atom, and error message.
  """
  @spec new(non_neg_integer(), reason(), String.t()) :: {:ok, t()} | {:error, :invalid_reason}
  def new(seq_num, reason, error_msg)
      when is_integer(seq_num) and seq_num >= 0 and is_binary(error_msg) do
    case Ecto.Type.cast(@reasons, reason) do
      {:ok, valid_reason} ->
        {:ok, %ExchangeFailed{seq_num: seq_num, reason: valid_reason, error_msg: error_msg}}

      _error ->
        {:error, :invalid_reason}
    end
  end

  @doc """
  Returns the list representation of an `%ExchangeFailed{}` ready for CBOR encoding.
  """
  @spec encode(t()) :: list()
  def encode(%ExchangeFailed{seq_num: seq_num, reason: reason, error_msg: error_msg}) do
    {:ok, code} = Ecto.Type.dump(@reasons, reason)
    [seq_num, code, error_msg]
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

  defp decode([seq_num, code, error_msg])
       when is_integer(seq_num) and seq_num >= 0 and
              is_integer(code) and code >= 0 and
              is_binary(error_msg) do
    case Ecto.Type.cast(@reasons, code) do
      {:ok, valid_reason} ->
        {:ok, %ExchangeFailed{seq_num: seq_num, reason: valid_reason, error_msg: error_msg}}

      _error ->
        {:error, :invalid_payload}
    end
  end

  defp decode(_), do: {:error, :invalid_payload}
end
