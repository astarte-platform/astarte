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

defmodule Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousDirective do
  @moduledoc """
  One RendezvousDirective = a list of RendezvousInstr.

  Represents a single directive grouping as defined in the FDO spec,
  i.e. a list of rendezvous instructions interpreted together.
  """
  use TypedStruct
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousDirective
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousInstr

  typedstruct enforce: true do
    field :instructions, [RendezvousInstr.t()]
  end

  def decode(instructions) when is_list(instructions) do
    instructions
    |> Enum.reduce_while([], fn
      instruction, acc ->
        case RendezvousInstr.decode(instruction) do
          {:ok, instruction} ->
            {:cont, [instruction | acc]}

          _ ->
            {:halt, {:error, :invalid_ownership_voucher}}
        end
    end)
    |> case do
      {:error, reason} ->
        {:error, reason}

      instruction_list ->
        {:ok, %RendezvousDirective{instructions: Enum.reverse(instruction_list)}}
    end
  end

  def encode(%RendezvousDirective{instructions: instructions}) do
    Enum.map(instructions, &RendezvousInstr.encode/1)
  end
end
