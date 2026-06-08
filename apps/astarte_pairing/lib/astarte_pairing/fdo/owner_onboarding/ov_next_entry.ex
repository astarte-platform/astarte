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
  TO2.OVNextEntry (Type 63).
  From Owner Onboarding Service to Device ROE.

  This message delivers a single Ownership Voucher entry to the Device.
  It is the response to TO2.GetOVNextEntry (Msg 62).

  The OVEntry is essentially a link in the certificate chain that allows the Device
  to verify that the current Owner is legitimate and traces back to the manufacturer.

  Spec Reference: 5.5.5 TO2.OVNextEntry, Type 63
  """
  use TypedStruct
  alias Astarte.Pairing.FDO.OwnerOnboarding.OVNextEntry

  typedstruct enforce: true do
    @typedoc "Structure for TO2.OVNextEntry message."

    # OVEntryNum
    # The index of the entry being sent. Must match the request received in Msg 62.
    field :entry_num, non_neg_integer()

    # OVEntry
    # The actual Ownership Voucher entry.
    # This is a COSE_Sign1 structure (encoded as binary).
    field :ov_entry, binary()
  end

  @doc """
  Converts the struct into a CBOR list.
  Format: [OVEntryNum, OVEntry]
  """
  def to_cbor_list(%__MODULE__{} = t) do
    [
      t.entry_num,
      t.ov_entry
    ]
  end

  @doc """
  Encodes the struct into a CBOR binary for transmission.
  """
  @spec encode(t()) :: binary()
  def encode(%OVNextEntry{} = t) do
    t
    |> to_cbor_list()
    |> CBOR.encode()
  end
end
