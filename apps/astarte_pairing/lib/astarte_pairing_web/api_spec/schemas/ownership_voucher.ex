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

defmodule Astarte.PairingWeb.ApiSpec.Schemas.OwnershipVoucher do
  @moduledoc false
  alias OpenApiSpex.Schema

  defmodule RequestBody do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            ownership_voucher: %Schema{
              type: :string,
              description:
                "The ownership voucher. It should be a base64-encoded string containing the CBOR representation of the ownership voucher."
            },
            key_name: %Schema{
              type: :string,
              description:
                "The name of the owner key stored in the secrets store to use for this voucher."
            },
            key_algorithm: %Schema{
              type: :string,
              enum: ["ecdsa-p256", "ecdsa-p384", "rsa-2048", "rsa-3072"],
              description: "The algorithm of the owner key."
            },
            replacement_guid: %Schema{
              type: :string,
              nullable: true,
              description: "Optional base64-encoded replacement GUID."
            },
            replacement_rendezvous_info: %Schema{
              type: :string,
              nullable: true,
              description: "Optional base64-encoded CBOR-encoded replacement rendezvous info."
            },
            replacement_public_key: %Schema{
              type: :string,
              nullable: true,
              description: "Optional PEM-encoded replacement public key."
            }
          },
          required: [:ownership_voucher, :key_name, :key_algorithm]
        }
      },
      required: [:data]
    })
  end

  defmodule List do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              guid: %Schema{type: :string, description: "The GUID of the device."},
              status: %Schema{
                type: :string,
                description: "The status of the ownership voucher."
              },
              output_guid: %Schema{
                type: :string,
                nullable: true,
                description: "The replacement GUID, if any."
              },
              input_voucher: %Schema{
                type: :string,
                nullable: true,
                description: "The PEM-encoded input ownership voucher."
              },
              output_voucher: %Schema{
                type: :string,
                nullable: true,
                description: "The PEM-encoded output ownership voucher, if any."
              }
            }
          }
        }
      }
    })
  end
end
