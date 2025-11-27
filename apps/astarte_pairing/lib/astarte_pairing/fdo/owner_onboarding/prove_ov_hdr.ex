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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.ProveOVHdrPayload do
  @moduledoc """
  Represents the internal payload for TO2.ProveOVHdr (Type 61).

  This payload initiates the validation of the Ownership Voucher and the Key Exchange.
  It is wrapped inside a COSE_Sign1 structure.

  **Important Note on COSE Headers:**
  According to Spec 5.5.3, this message MUST include specific parameters in the 
  COSE Unprotected Headers which are NOT part of this payload struct:
  1. `CUPHNonce` (NonceTO2ProveDv): Used for freshness in TO2.ProveDevice.
  2. `CUPHOwnerPubKey`: The Owner Public Key used to verify this message's signature.

  Reference Section: 5.5.3 TO2.ProveOVHdr
  """
  use TypedStruct
  alias Astarte.Pairing.FDO.OwnerOnboarding.ProveOVHdrPayload

  typedstruct enforce: true do
    @typedoc "The 8-element payload to be signed inside COSE_Sign1."

    # 1. OVHeader
    # The header of the Ownership Voucher. 
    # Contains the GUID, Device Info, and the initial Owner Public Key.
    field :ov_header, binary()

    # 2. NumOVEntries
    # The number of Ownership Voucher entries that will follow in subsequent messages.
    # Must be < 256. If 0, it implies a re-manufacturing scenario.
    field :num_ov_entries, non_neg_integer()

    # 3. HMac
    # HMAC-SHA256 or HMAC-SHA384 of the OVHeader.
    # Matches the value stored in the Device during Device Initialization (DI).
    # Verifies the device integrity (ensures it hasn't been wiped/re-initialized).
    field :hmac, binary()

    # 4. NonceTO2ProveOV
    # The nonce received from the Device in TO2.HelloDevice.
    # Proves liveness and prevents replay attacks of the HelloDevice message.
    field :nonce_hello_device, binary()

    # 5. eBSigInfo
    # Contains information about the signature scheme used by the Device 
    # for attestation (e.g., key type, curve).
    field :eb_sig_info, map()

    # 6. xAKeyExchange
    # The Owner's ephemeral public key contribution to the Key Exchange (Point A).
    # FDO uses ECDH (Elliptic Curve Diffie-Hellman).
    field :xa_key_exchange, binary()

    # 7. helloDeviceHash
    # A SHA hash of the full TO2.HelloDevice message received earlier.
    # Allows the Device to verify that the Hello message was not tampered with 
    # by a Man-in-the-Middle (MitM) before reaching the Owner.
    field :hello_device_hash, binary()

    # 8. maxOwnerMessageSize
    # Indicates the maximum message size the Owner Service can handle.
    # The Device uses this to fragment large responses if necessary.
    field :max_owner_message_size, non_neg_integer()
  end

  @doc """
  Converts the struct into the raw CBOR list required for the COSE payload.
  Order: [OVHeader, NumOVEntries, HMac, NonceTO2ProveOV, eBSigInfo, xAKeyExchange, HelloDeviceHash, MaxOwnerMessageSize]
  """
  def build_to2_proveovhdr_payload(%ProveOVHdrPayload{} = p) do
    [
      p.ov_header,
      p.num_ov_entries,
      p.hmac,
      p.nonce_hello_device,
      p.eb_sig_info,
      p.xa_key_exchange,
      p.hello_device_hash,
      p.max_owner_message_size
    ]
  end

  @doc """
  Encodes the ProveOVHdrPayload struct into CBOR format (binary).
  This binary is what will be subsequently signed and wrapped in the COSE_Sign1 structure.
  """
  @spec encode(t()) :: binary()
  def encode(%ProveOVHdrPayload{} = p) do
    p
    |> build_to2_proveovhdr_payload()
    |> CBOR.encode()
  end
end
