#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.PairingWeb.ApiSpec.Schemas.Fdo do
  @moduledoc false
  alias OpenApiSpex.Schema

  defmodule HelloDeviceRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HelloDeviceRequest",
      type: :array,
      description: """
      TO2.HelloDevice CBOR array:
      [maxDeviceMessageSize, Guid, NonceTO2ProveOV, kexSuiteName, cipherSuiteName, eASigInfo]
      """,
      items: %Schema{
        type: :string,
        format: :binary
      },
      minItems: 6,
      maxItems: 6,
      example: [
        1400,
        "123e4567-e89b-12d3-a456-426614174000",
        "nonce",
        "kex",
        "cipher",
        "sig"
      ]
    })
  end

  defmodule GetOVNextEntryRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GetOVNextEntryRequest",
      type: :array,
      description:
        "Acknowledges the previous message and requests the next Ownership Voucher Entry. The integer argument,
OVEntryNum, is the number of the entry, where the first entry is zero (0).",
      items: %Schema{
        type: :string,
        format: :binary
      },
      example: [
        1
      ]
    })
  end

  defmodule ProveDeviceRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ProveDeviceRequest",
      type: :array,
      description:
        "Proves the provenance of the Device to the new owner, using the entity attestation token based on the challenge
                      NonceTO2ProveDv sent as TO2.ProveOVHdr.UnprotectedHeaders.CUPHNonce. The signature is verified using the
                      device certificate chain contained in the Ownership Voucher. If the signature cannot be verified, or fails to verify,
                      the connection is terminated with an error message.",
      items: %Schema{
        type: :string,
        format: :binary
      },
      example: [
        "xBKeyExchange"
      ]
    })
  end

  defmodule DeviceServiceInfoStartRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DeviceServiceInfoStartRequest",
      type: :array,
      description:
        "This message signals a state change between the authentication phase of the protocol and the provisioning
        phase (ServiceInfo) negotiation.",
      items: %Schema{
        type: :string,
        format: :binary
      },
      example: [
        "ReplacementHMac",
        "maxOwnerServiceInfoSz"
      ]
    })
  end

  defmodule DeviceServiceInfoRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DeviceServiceInfoRequest",
      type: :array,
      description:
        "Sends as many Device to Owner ServiceInfo entries as will conveniently fit into a message, based on protocol
and Device constraints. This message is part of a loop with TO2.OwnerServiceInfo.",
      items: %Schema{
        type: :string,
        format: :binary
      },
      example: [
        "IsMoreServiceInfo",
        "ServiceInfo"
      ]
    })
  end

  defmodule DoneRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DoneRequest",
      type: :array,
      description: "Indicates successful completion of the Transfer of Ownership.",
      items: %Schema{
        type: :string,
        format: :binary
      },
      example: [
        "NonceTO2ProveDv"
      ]
    })
  end
end
