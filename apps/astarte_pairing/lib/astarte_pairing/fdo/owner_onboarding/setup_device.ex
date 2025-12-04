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

  1. This payload is encoded to CBOR.
  2. Then wrapped in a `COSE_Sign1` signed by the **Owner2Key** (the new key).
  3. The `COSE_Sign1` bytes are then Encrypted (COSE_Encrypt0/Mac0) before transmission.

  Reference Section: 5.5.7 TO2.SetupDevice
  """
  use TypedStruct
  alias Astarte.Pairing.FDO.Types.PublicKey

  typedstruct enforce: true do
    @typedoc "The 4-element payload to be signed inside COSE_Sign1."

    # 1. RendezvousInfo
    # Replacement for the device's RendezvousInfo.
    # It is a complex list of instructions (directives). 
    # Usually passed as a raw CBOR binary if pre-built, or a list of maps/lists.
    field :rendezvous_info, list() | binary()

    # 2. Guid
    # Replacement for the device GUID. 
    field :guid, binary()

    # 3. NonceTO2SetupDv
    # The Nonce received from the Device in TO2.ProveDevice (Type 64).
    # Ensures this Setup command is linked to the current authenticated session.
    field :nonce_setup_device, binary()

    # 4. Owner2Key
    # The New Owner Public Key.
    # This is the key the device will trust from now on.
    field :owner2_key, PublicKey.t()
  end

  @doc """
  Converts the struct into the standard FDO CBOR list format.
  Order: [RendezvousInfo, Guid, Nonce, Owner2Key]
  """
  def to_cbor_list(%__MODULE__{} = p) do
    [
      p.rendezvous_info,
      COSE.tag_as_byte(p.guid),
      COSE.tag_as_byte(p.nonce_setup_device),
      PublicKey.encode(p.owner2_key)
    ]
  end

  @doc """
  Encodes the payload to binary CBOR. 
  This binary is what gets signed in the payload field of the COSE_Sign1.
  """
  def encode(%__MODULE__{} = p) do
    p
    |> to_cbor_list()
    |> CBOR.encode()
  end
end
