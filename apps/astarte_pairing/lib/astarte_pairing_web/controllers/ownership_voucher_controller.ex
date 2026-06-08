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

defmodule Astarte.PairingWeb.OwnershipVoucherController do
  use Astarte.PairingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.Pairing.FDO
  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnershipVoucher.CreateRequest
  alias OpenApiSpex.Schema

  action_fallback Astarte.PairingWeb.FallbackController

  tags ["fdo"]

  operation :create,
    summary: "Create an ownership voucher",
    description: "Create an ownership voucher for a device and claim it.",
    operation_id: "createOwnershipVoucher",
    security: [%{"JWT" => []}],
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm.",
        type: :string,
        required: true
      ]
    ],
    request_body:
      {"Ownership Voucher Creation Request", "application/json",
       %Schema{
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
               private_key: %Schema{
                 type: :string,
                 description:
                   "The private key in PEM format corresponding to the public key used in the ownership voucher."
               }
             },
             required: [:ownership_voucher, :private_key]
           }
         },
         required: [:data]
       }},
    responses: [
      ok: {"Ownership voucher created successfully", nil, nil},
      bad_request: {"Invalid request body", nil, nil},
      unauthorized: {"Unauthorized", nil, nil},
      not_found: {"Realm not found", nil, nil},
      internal_server_error: {"Internal server error", nil, nil}
    ]

  def create(conn, %{
        "data" => data,
        "realm_name" => realm_name
      }) do
    create = CreateRequest.changeset(%CreateRequest{}, data)

    with {:ok, create} <- Ecto.Changeset.apply_action(create, :insert),
         %CreateRequest{
           decoded_ownership_voucher: decoded_ownership_voucher,
           cbor_ownership_voucher: cbor_ownership_voucher,
           private_key: private_key,
           extracted_private_key: extracted_private_key,
           device_guid: device_guid
         } = create,
         :ok <-
           OwnershipVoucher.save_voucher(
             realm_name,
             cbor_ownership_voucher,
             device_guid,
             private_key
           ),
         :ok <-
           FDO.claim_ownership_voucher(
             realm_name,
             decoded_ownership_voucher,
             extracted_private_key
           ) do
      send_resp(conn, 200, "")
    end
  end
end
