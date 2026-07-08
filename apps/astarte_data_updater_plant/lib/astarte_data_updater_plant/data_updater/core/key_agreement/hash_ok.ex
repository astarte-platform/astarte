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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HashOk do
  @moduledoc """
  Represents the HashOk (type 3) key-agreement message published on the
  `<realm>/<device>/control/keyAgreement/3` MQTT control topic.

  Sent by either party to acknowledge that a received `SecretHash` (type 2)
  message matched the locally derived shared secret. It carries the
  `seq_num` of the `SecretHash` message being acknowledged, so that the
  counterpart can associate this confirmation with the correct request.

  ## Message structure:

      [
        seq_num :: uint   # sequence number taken from the associated SecretHash message
      ]
  """

  use TypedStruct

  alias __MODULE__, as: HashOk

  typedstruct enforce: true do
    @typedoc "HashOk acknowledgement message referencing the associated SecretHash seq_num."
    field :seq_num, non_neg_integer()
  end

  @doc """
  Returns the list representation of a `%HashOk{}` ready for CBOR encoding.
  """
  @spec encode(t()) :: list()
  def encode(%HashOk{seq_num: seq_num}), do: [seq_num]

  @doc """
  CBOR-encodes a `%HashOk{}` for transmission.
  """
  @spec cbor_encode(t()) :: binary()
  def cbor_encode(%HashOk{} = msg), do: msg |> encode() |> CBOR.encode()

  @doc """
  Decodes and validates a raw CBOR payload received on the
  `control/keyAgreement/3` topic.
  """
  @spec cbor_decode(binary()) :: {:ok, t()} | {:error, :invalid_payload}
  def cbor_decode(payload) when is_binary(payload) do
    case CBOR.decode(payload) do
      {:ok, raw, _rest} -> decode(raw)
      {:error, _reason} -> {:error, :invalid_payload}
    end
  end

  defp decode([seq_num]) when is_integer(seq_num) and seq_num >= 0 do
    {:ok, %HashOk{seq_num: seq_num}}
  end

  defp decode(_), do: {:error, :invalid_payload}
end
