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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.OVNextEntry do
  @moduledoc """
  TO2.OVNextEntry (Msg 63): The Owner sends a specific Ownership Voucher entry.

  From Owner Onboarding Service to Device ROE.
  """
  use TypedStruct

  typedstruct enforce: true do
    @typedoc "Structure for TO2.OVNextEntry message."

    # The index of the entry being sent. Must match the request from Msg 62.
    field :entry_num, non_neg_integer()

    # The actual Ownership Voucher entry (binary blob/COSE object).
    field :ov_entry, binary()
  end

  @doc """
  Converts the struct into a CBOR list for transmission.
  Format: [OVEntryNum, OVEntry]
  """
  def to_cbor_list(%__MODULE__{} = t) do
    [
      t.entry_num,
      t.ov_entry
    ]
  end
end
