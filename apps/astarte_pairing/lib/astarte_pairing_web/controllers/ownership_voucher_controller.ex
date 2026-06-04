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

  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.FDO.TO0
  alias Astarte.PairingWeb.ApiSpec.Schemas.OwnershipVoucher, as: OVApiSpec
  alias Astarte.PairingWeb.OwnershipVoucherView
  alias Astarte.Secrets.Core, as: SecretsCore
  alias OpenApiSpex.Schema

  action_fallback Astarte.PairingWeb.FallbackController

  tags ["fdo"]

  operation :register,
    summary: "Register an ownership voucher",
    description: "Register an ownership voucher for a device and claim it.",
    operation_id: "registerOwnershipVoucher",
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
      {"Ownership Voucher Registration Request", "application/json", OVApiSpec.RequestBody},
    responses: [
      ok: {"Ownership voucher registered successfully", nil, nil},
      bad_request: {"Invalid request body", nil, nil},
      unauthorized: {"Unauthorized", nil, nil},
      not_found: {"Realm not found", nil, nil},
      internal_server_error: {"Internal server error", nil, nil}
    ]

  operation :list_ownership_vouchers,
    summary: "List ownership vouchers",
    description: "Returns the list of all ownership vouchers registered in the realm.",
    operation_id: "listOwnershipVouchers",
    security: [%{"JWT" => []}],
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm.",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok: {"List of ownership vouchers", "application/json", OVApiSpec.List},
      unauthorized: {"Unauthorized", nil, nil},
      not_found: {"Realm not found", nil, nil},
      internal_server_error: {"Internal server error", nil, nil}
    ]

  operation :owner_keys_for_voucher,
    summary: "List owner keys compatible with an ownership voucher",
    description:
      "Returns the list of registered owner keys that are compatible with the given ownership voucher.",
    operation_id: "ownerKeysForVoucher",
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
      {"Owner Keys for Voucher Request", "application/json",
       %Schema{
         type: :object,
         properties: %{
           data: %Schema{
             type: :object,
             properties: %{
               ownership_voucher: %Schema{
                 type: :string,
                 description: "The base64-encoded ownership voucher to match keys against."
               }
             },
             required: [:ownership_voucher]
           }
         },
         required: [:data]
       }},
    responses: [
      ok:
        {"Compatible owner keys", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :object,
               description: "A map from key algorithm name to the list of compatible key names.",
               additionalProperties: %Schema{
                 type: :array,
                 items: %Schema{type: :string}
               }
             }
           }
         }},
      bad_request: {"Invalid request body", nil, nil},
      unauthorized: {"Unauthorized", nil, nil},
      not_found: {"Realm not found", nil, nil},
      unprocessable_entity: {"Missing ownership_voucher parameter", nil, nil},
      internal_server_error: {"Internal server error", nil, nil}
    ]

  @doc """
  Validates an FDO Ownership Voucher load request and register the OV in the database.

  Returns `200 OK` with the owner public key PEM on success.
  """
  def register(conn, %{"data" => data, "realm_name" => realm_name}) do
    with {:ok, req} <-
           LoadRequest.changeset(%LoadRequest{}, Map.put(data, "realm_name", realm_name))
           |> Ecto.Changeset.apply_action(:insert),
         :ok <-
           OwnershipVoucher.save_voucher(realm_name, %{
             voucher_data: req.cbor_ownership_voucher,
             guid: req.device_guid,
             key_name: req.key_name,
             key_algorithm: req.key_algorithm,
             replacement_guid: req.replacement_guid,
             replacement_rendezvous_info: req.decoded_replacement_rendezvous_info,
             replacement_public_key: req.decoded_replacement_public_key
           }),
         :ok <-
           TO0.claim_ownership_voucher(
             realm_name,
             req.decoded_ownership_voucher,
             req.extracted_owner_key
           ) do
      json(conn, %{
        data: %{
          public_key: req.extracted_owner_key.public_pem,
          guid: UUID.binary_to_string!(req.device_guid)
        }
      })
    end
  end

  @doc """
  List ownership vouchers.
  """
  def list_ownership_vouchers(conn, %{"realm_name" => realm_name}) do
    with {:ok, vouchers} <- OwnershipVoucher.list(realm_name) do
      conn
      |> put_view(OwnershipVoucherView)
      |> render("list_vouchers.json", ownership_vouchers: vouchers)
    end
  end

  @doc """
  Returns the list of registered owner keys that are compatible with the
  given ownership voucher.

  Returns `200 OK` with `{"data": {"<algorithm>": ["key_name", ...]}}` on success.
  """
  def owner_keys_for_voucher(conn, %{"data" => data, "realm_name" => realm_name}) do
    with {:ok, pem} <- ensure_ownership_voucher_parameter(data),
         {:ok, voucher} <- OwnershipVoucher.decode_binary_voucher(pem),
         key_algorithm = OwnershipVoucher.key_algorithm(voucher),
         {:ok, keys_map} <- SecretsCore.get_keys(realm_name, key_algorithm) do
      json(conn, %{data: keys_map})
    end
  end

  defp ensure_ownership_voucher_parameter(%{"ownership_voucher" => pem})
       when is_binary(pem) and pem != "",
       do: {:ok, pem}

  defp ensure_ownership_voucher_parameter(_params),
    do: {:error, :missing_ownership_voucher}
end
