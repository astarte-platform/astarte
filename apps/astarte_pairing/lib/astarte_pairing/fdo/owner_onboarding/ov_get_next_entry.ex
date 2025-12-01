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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.GetOVNextEntry do
  @moduledoc """
  TO2.GetOVNextEntry (Type 62) structure.
  From Device ROE to Owner Onboarding Service.

  This message is sent by the Device to request a specific entry from the 
  Ownership Voucher chain. It acknowledges the previous message (ProveOVHdr or 
  a previous OVNextEntry) and asks for the next step.

  Spec Reference: 5.5.4 TO2.GetOVNextEntry, Type 62
  """
  use TypedStruct
  alias Astarte.Pairing.FDO.OwnerOnboarding.GetOVNextEntry

  typedstruct enforce: true do
    @typedoc "Structure for TO2.GetOVNextEntry message."

    # OVEntryNum
    # The index of the Ownership Voucher entry requested by the Device.
    # - The first entry is index 0.
    # - The Device increments this counter in subsequent requests until the chain is complete.
    field :entry_num, non_neg_integer()
  end

  @doc """
  Decodes the raw CBOR binary into the struct.
  """
  @spec decode(binary()) :: {:ok, t()} | :error
  def decode(cbor_binary) do
    case CBOR.decode(cbor_binary) do
      {:ok, [entry_num], _rest} when is_integer(entry_num) and entry_num >= 0 ->
        {:ok, %GetOVNextEntry{entry_num: entry_num}}

      _ ->
        :error
    end
  end
end
