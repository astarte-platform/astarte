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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.SetupDevicePayload do
  @moduledoc """
  Represents the internal payload for TO2.SetupDevice (Type 65).

  This structure contains the new credentials and configuration that the Device 
  will adopt upon successful completion of the protocol (at TO2.Done).

  This payload is not sent as raw CBOR but is encapsulated within a 
  `COSE_Sign1` object signed by the new Owner Key (Owner2Key).

  Reference Section: 5.5.7 TO2.SetupDevice
  """
  use TypedStruct

  typedstruct enforce: true do
    @typedoc "The 4-element payload to be signed inside COSE_Sign1."

    # 1. RendezvousInfo
    # Replacement for the device's RendezvousInfo.
    # Defines how the device connects to the new Owner's infrastructure (e.g., Astarte URL).
    # Can be a raw binary (if pre-encoded) or a list of instructions.
    field :rendezvous_info, list() | binary()

    # 2. Guid
    # Replacement for the device GUID.
    # Usually persists the existing GUID, but allows reassignment if necessary.
    field :guid, binary()

    # 3. NonceTO2SetupDv
    # The Nonce received from the Device in the previous message (TO2.ProveDevice).
    # Including this here proves the freshness of the signature and links 
    # this setup command to the active session initiated by the device.
    field :nonce_setup_device, binary()

    # 4. Owner2Key
    # The new Owner Public Key.
    # The device will store this key and use it to verify future ownership commands.
    # Note: The COSE_Sign1 wrapping this payload MUST be signed by the private key
    # corresponding to this public key.
    field :owner2_key, binary()
  end

  @doc """
  Converts the struct into the CBOR list [RendezvousInfo, Guid, Nonce, Owner2Key].
  """
  def to_cbor_list(%__MODULE__{} = p) do
    [
      p.rendezvous_info,
      p.guid,
      p.nonce_setup_device,
      p.owner2_key
    ]
  end
end
