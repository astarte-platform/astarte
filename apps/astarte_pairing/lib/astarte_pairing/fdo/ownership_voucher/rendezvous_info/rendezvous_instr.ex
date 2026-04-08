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

defmodule Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousInstr do
  @moduledoc "A single rendezvous instruction `[RVVariable, RVValue]`."
  use TypedStruct
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousInstr
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RVVariable

  typedstruct enforce: true do
    field :rv_variable, RVVariable.t()
    field :rv_value, binary()
  end

  def decode([u8_rv_variable, value]) do
    with {:ok, rv_variable} <- RVVariable.decode(u8_rv_variable),
         {:ok, rv_value} <- decode_rv_value(value) do
      {:ok, %RendezvousInstr{rv_variable: rv_variable, rv_value: rv_value}}
    end
  end

  def encode(%RendezvousInstr{rv_variable: variable, rv_value: value}) do
    [RVVariable.encode(variable), encode_rv_value(value)]
  end

  defp decode_rv_value(%CBOR.Tag{tag: :bytes, value: rv_value}) do
    {:ok, rv_value}
  end

  defp decode_rv_value(_), do: :error

  defp encode_rv_value(v) when is_binary(v), do: COSE.tag_as_byte(v)
end
