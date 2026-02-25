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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo do
  @moduledoc """
  TO2.DeviceServiceInfo (Msg 68).
  From Device ROE to Owner Onboarding Service.

  This message conveys ServiceInfo entries from the Device to the Owner.
  It is part of a loop with TO2.OwnerServiceInfo and handles flow control.
  """
  use TypedStruct
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo
  alias Astarte.FDO.ServiceInfo

  typedstruct enforce: true do
    @typedoc "Structure for TO2.DeviceServiceInfo message."

    # IsMoreServiceInfo
    # Boolean flag indicating flow control status:
    # 1. Fragmentation: If true, the Device has more data to send that didn't fit.
    #    The Owner must reply with an empty OwnerServiceInfo.
    # 2. Yield: If the PREVIOUS OwnerServiceInfo had IsMore=true, this must be false.
    field :is_more_service_info, boolean()

    # ServiceInfo
    # A list containing the Device's ServiceInfo instructions (Key-Value pairs).
    # - On the first message, it usually includes 'devmod' (device modules).
    # - Must be empty if the Device is yielding to the Owner (responding to Owner's IsMore=true).
    field :service_info, map()
  end

  @doc """
  Converts the struct into a CBOR list for transmission.
  Format: [IsMoreServiceInfo, ServiceInfo]
  """
  def to_cbor_list(%DeviceServiceInfo{} = t) do
    [
      t.is_more_service_info,
      t.service_info
    ]
  end

  @doc """
  Decodes the raw CBOR payload into the struct.
  Validates that IsMoreServiceInfo is a boolean and ServiceInfo is a list.
  """
  @spec cbor_decode(binary()) :: {:ok, t()} | {:error, atom()}
  def cbor_decode(cbor_payload) do
    case CBOR.decode(cbor_payload) do
      {:ok, payload, _} -> decode(payload)
      _ -> {:error, :message_body_error}
    end
  end

  def decode(payload) do
    case payload do
      [is_more, service_info_list] -> validate_and_build(is_more, service_info_list)
      _ -> {:error, :message_body_error}
    end
  end

  defp validate_and_build(is_more, info) do
    with :ok <- validate_bool(is_more),
         {:ok, service_info_map} <- ServiceInfo.decode_map(info) do
      message = %DeviceServiceInfo{
        is_more_service_info: is_more,
        service_info: service_info_map
      }

      {:ok, message}
    else
      _ -> {:error, :message_body_error}
    end
  end

  defp validate_bool(val) when is_boolean(val), do: :ok
  defp validate_bool(_), do: {:error, :invalid_is_more_type}
end
