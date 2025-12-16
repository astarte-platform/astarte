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
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.Pairing.FDO.Types.Hash

  @default_max_owner_service_info_sz 1400

  typedstruct enforce: true do
    @typedoc "Structure for TO2.DeviceServiceInfoReady message."

    # ReplacementHMac
    # Used by the Owner to create a new Ownership Voucher for the device (resale).
    # If nil, it indicates acceptance of the Credential Reuse protocol.
    field :replacement_hmac, Hash.t() | nil

    # maxOwnerServiceInfoSz
    # If nil, the default recommended limit (1300 bytes) is assumed.
    field :max_owner_service_info_sz, non_neg_integer() | nil
  end

  @doc """
  Decodes the raw CBOR list into the struct.
  Expected format: [ReplacementHMac, maxOwnerServiceInfoSz]
  """
  def from_cbor_list([hmac, size]) do
    %DeviceServiceInfoReady{
      replacement_hmac: hmac,
      max_owner_service_info_sz: size
    }
  end

  @doc """
  Decodes the raw CBOR payload into the DeviceServiceInfoReady struct.
  It validates that the structure is a list of two elements and checks types.
  """
  @spec cbor_decode(binary()) :: {:ok, t()} | {:error, atom()}
  def cbor_decode(cbor_payload) do
    case CBOR.decode(cbor_payload) do
      {:ok, payload, _} -> DeviceServiceInfoReady.decode(payload)
      _ -> {:error, :message_body_error}
    end
  end

  def decode(payload) do
    case payload do
      [hmac, size] -> validate_and_build(hmac, size)
      _ -> {:error, :message_body_error}
    end
  end

  defp validate_and_build(nil, size) do
    with :ok <- validate_size(size) do
      message =
        %DeviceServiceInfoReady{
          replacement_hmac: nil,
          max_owner_service_info_sz: size
        }

      {:ok, message}
    end
  end

  defp validate_and_build(hmac, size) do
    with {:ok, hmac} <- Hash.decode(hmac),
         :ok <- validate_size(size),
         size <- normalize_owner_max_size(size) do
      message =
        %DeviceServiceInfoReady{
          replacement_hmac: hmac,
          max_owner_service_info_sz: size
        }

      {:ok, message}
    end
  end

  # Spec: maxOwnerServiceInfoSz = uint / null
  defp validate_size(nil), do: :ok
  defp validate_size(size) when is_integer(size) and size >= 0, do: :ok
  defp validate_size(_), do: {:error, :invalid_size_type}

  defp normalize_owner_max_size(nil), do: @default_max_owner_service_info_sz
  defp normalize_owner_max_size(0), do: @default_max_owner_service_info_sz
  defp normalize_owner_max_size(size), do: size
end
