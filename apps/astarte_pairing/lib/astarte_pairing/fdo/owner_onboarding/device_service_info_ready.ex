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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady do
  @moduledoc """
  TO2.DeviceServiceInfoReady (Msg 66).
  From Device ROE to Owner Onboarding Service.

  This message signals the transition from the Authentication phase to the 
  Provisioning phase (ServiceInfo negotiation).
  """
  use TypedStruct

  typedstruct enforce: true do
    @typedoc "Structure for TO2.DeviceServiceInfoReady message."

    # ReplacementHMac
    # Used by the Owner to create a new Ownership Voucher for the device (resale).
    # If nil, it indicates acceptance of the Credential Reuse protocol.
    field :replacement_hmac, binary() | nil

    # maxOwnerServiceInfoSz
    # If nil, the default recommended limit (1300 bytes) is assumed.
    field :max_owner_service_info_sz, non_neg_integer() | nil
  end

  @doc """
  Decodes the raw CBOR list into the struct.
  Expected format: [ReplacementHMac, maxOwnerServiceInfoSz]
  """
  def from_cbor_list([hmac, size]) do
    %__MODULE__{
      replacement_hmac: hmac,
      max_owner_service_info_sz: size
    }
  end
end
