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

defmodule Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo do
  @moduledoc """
  Implementation of FDO RendezvousInfo type.
  """

  use TypedStruct
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousDirective

  typedstruct enforce: true do
    field :directives, [RendezvousDirective.t()]
  end

  @doc """
  Decode CBOR-decoded RendezvousInfo into structs.
  """
  @spec decode(list(list())) :: {:ok, t()} | {:error, any()}
  def decode(directives) when is_list(directives) do
    directives
    |> Enum.reduce_while([], fn instructions, acc ->
      case RendezvousDirective.decode(instructions) do
        {:ok, directive} -> {:cont, [directive | acc]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} ->
        {:error, reason}

      list ->
        result = %RendezvousInfo{directives: Enum.reverse(list)}
        {:ok, result}
    end
  end

  def decode(_), do: {:error, :invalid_ownership_voucher}

  @doc "Encode RendezvousInfo into CBOR-compatible terms."
  @spec encode(RendezvousInfo.t()) :: list()
  def encode(rv_info) do
    Enum.map(rv_info.directives, &RendezvousDirective.encode/1)
  end
end
