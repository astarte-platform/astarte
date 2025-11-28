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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfoReady do
  @moduledoc """
  TO2.OwnerServiceInfoReady (Msg 67).
  From Owner Onboarding Service to Device ROE.

  This message responds to TO2.DeviceServiceInfoReady and indicates that the 
  Owner Onboarding Service is ready to start exchanging ServiceInfo.
  """
  use TypedStruct

  typedstruct enforce: true do
    @typedoc "Structure for TO2.OwnerServiceInfoReady message."

    # Indicates the maximum size of ServiceInfo messages that the Owner 
    # is able to process from the Device.
    # - If nil: indicates the recommended maximum size (1300 bytes).
    # - If uint16: specifies a custom size limit.
    field :max_device_service_info_sz, non_neg_integer() | nil
  end

  @doc """
  Converts the struct into a CBOR list for transmission.
  Format: [maxDeviceServiceInfoSz]
  """
  def to_cbor_list(%__MODULE__{} = t) do
    [
      t.max_device_service_info_sz
    ]
  end
end
