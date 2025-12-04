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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfo do
  @moduledoc """
  TO2.OwnerServiceInfo (Msg 69).
  From Owner Onboarding Service to Device ROE.

  This message conveys ServiceInfo instructions from the Owner to the Device.
  It manages flow control (fragmentation) and termination of the ServiceInfo phase.
  """
  use TypedStruct
  alias Astarte.Pairing.FDO.Types.ServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfo

  typedstruct enforce: true do
    @typedoc "Structure for TO2.OwnerServiceInfo message."

    # IsMoreServiceInfo
    # Boolean flag indicating if the Owner has more data to send that didn't fit in this message.
    # - If true: The Device must acknowledge with an empty DeviceServiceInfo, allowing the Owner to continue.
    # - If the PREVIOUS DeviceServiceInfo had IsMore=true, this field MUST be false (Owner yields to Device).
    field :is_more_service_info, boolean()

    # IsDone
    # Boolean flag indicating if the Owner has finished the entire provisioning process.
    # - If true: The ServiceInfo phase ends. The Device will proceed to process data and eventually send TO2.Done.
    # - If true: The 'service_info' field in this message (and subsequent keepalives) must be empty.
    field :is_done, boolean()

    # ServiceInfo
    # A list containing the actual ServiceInfo instructions (Key-Value pairs).
    # Examples: "fdo_sys:filedesc" (write file), "fdo_sys:exec" (execute script).
    field :service_info, map()
  end

  @doc """
  Converts the struct into a CBOR list for transmission.
  Format: [IsMoreServiceInfo, IsDone, ServiceInfo]
  """
  def to_cbor_list(%__MODULE__{} = t) do
    [
      t.is_more_service_info,
      t.is_done,
      ServiceInfo.encode_map(t.service_info)
    ]
  end

  @doc """
  Encodes the struct into a CBOR binary ready for transmission.
  """
  @spec encode(t()) :: binary()
  def encode(%OwnerServiceInfo{} = t) do
    t
    |> to_cbor_list()
    |> CBOR.encode()
  end
end
