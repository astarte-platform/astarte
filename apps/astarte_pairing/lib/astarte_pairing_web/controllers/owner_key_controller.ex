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

defmodule Astarte.PairingWeb.OwnerKeyController do
  use Astarte.PairingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.PairingWeb.ApiSpec.Schemas.OwnerKey
  alias Astarte.Secrets
  alias Astarte.Secrets.OwnerKeyInitialization
  alias Astarte.Secrets.OwnerKeyInitializationOptions
  alias OpenApiSpex.Schema

  require Logger

  action_fallback Astarte.PairingWeb.FallbackController

  tags ["fdo"]

  operation :create_or_upload_key,
    summary: "Create or upload an owner key",
    description:
      "Creates a new owner key with the given algorithm, or uploads an existing private key.",
    operation_id: "createOrUploadOwnerKey",
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
      {"Create or Upload Owner Key Request", "application/json",
       OwnerKey.CreateOrUploadOwnerKeyRequest},
    responses: [
      ok:
        {"Owner key created or uploaded successfully", "text/plain",
         %Schema{
           type: :string,
           description:
             "The PEM-encoded public key when action is \"create\", or an empty string when action is \"upload\"."
         }},
      bad_request: {"Invalid request body", nil, nil},
      unauthorized: {"Unauthorized", nil, nil},
      not_found: {"Realm not found", nil, nil},
      unprocessable_entity: {"Validation error", nil, nil},
      internal_server_error: {"Internal server error", nil, nil}
    ]

  operation :list_keys,
    summary: "List owner keys",
    description: "Returns all registered owner keys grouped by algorithm.",
    operation_id: "listOwnerKeys",
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
      ok:
        {"Owner keys grouped by algorithm", "application/json",
         %Schema{
           type: :object,
           description: "A map from algorithm name to list of key names.",
           additionalProperties: %Schema{
             type: :array,
             items: %Schema{type: :string}
           }
         }},
      unauthorized: {"Unauthorized", nil, nil},
      not_found: {"Realm not found", nil, nil},
      internal_server_error: {"Internal server error", nil, nil}
    ]

  operation :get_keys_for_algorithm,
    summary: "List owner keys for an algorithm",
    description: "Returns all registered owner keys for the specified algorithm.",
    operation_id: "getOwnerKeysForAlgorithm",
    security: [%{"JWT" => []}],
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm.",
        type: :string,
        required: true
      ],
      key_algorithm: [
        in: :path,
        description: "The key algorithm (e.g. es256, es384, rs256, rs384).",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok:
        {"Owner keys for the algorithm", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :object,
               description: "A map from algorithm name to list of key names.",
               additionalProperties: %Schema{
                 type: :array,
                 items: %Schema{type: :string}
               }
             }
           }
         }},
      unauthorized: {"Unauthorized", nil, nil},
      not_found: {"Realm not found", nil, nil},
      unprocessable_entity: {"Unknown key algorithm", nil, nil},
      internal_server_error: {"Internal server error", nil, nil}
    ]

  operation :get_key,
    summary: "Get an owner key",
    description: "Returns a specific owner key by algorithm and name.",
    operation_id: "getOwnerKey",
    security: [%{"JWT" => []}],
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm.",
        type: :string,
        required: true
      ],
      key_algorithm: [
        in: :path,
        description: "The key algorithm (e.g. es256, es384, rs256, rs384).",
        type: :string,
        required: true
      ],
      key_name: [
        in: :path,
        description: "The name of the key.",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok:
        {"Owner key details", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :object,
               properties: %{
                 key_name: %Schema{type: :string, description: "The name of the key."},
                 public_key: %Schema{
                   type: :string,
                   description: "The PEM-encoded public key."
                 }
               }
             }
           }
         }},
      unauthorized: {"Unauthorized", nil, nil},
      not_found: {"Key not found", nil, nil},
      unprocessable_entity: {"Unknown key algorithm", nil, nil},
      internal_server_error: {"Internal server error", nil, nil}
    ]

  def create_or_upload_key(
        conn,
        %{
          "data" => data,
          "realm_name" => realm_name
        }
      ) do
    # TODO handle userID when available
    create_or_upload_changeset =
      OwnerKeyInitializationOptions.changeset(%OwnerKeyInitializationOptions{}, data)

    with {:ok, create_or_upload_changeset} <-
           Ecto.Changeset.apply_action(create_or_upload_changeset, :insert),
         {:ok, resp} <-
           OwnerKeyInitialization.create_or_upload(create_or_upload_changeset, realm_name) do
      # the successful resp will be a public key (when creating) or an empty string (when uploading)
      send_resp(conn, 200, resp)
    end
  end

  @supported_key_algorithms [:es256, :es384, :rs256, :rs384]
  def list_keys(
        conn,
        %{
          "realm_name" => realm_name
        }
      ) do
    with {:ok, keys} <-
           Secrets.Core.get_keys(realm_name, @supported_key_algorithms) do
      send_resp(conn, 200, Jason.encode!(keys))
    end
  end

  def get_keys_for_algorithm(conn, %{
        "realm_name" => realm_name,
        "key_algorithm" => key_algorithm
      }) do
    with {:ok, algorithm} <- Secrets.Core.string_to_key_type(key_algorithm),
         {:ok, keys} <- Secrets.Core.get_keys(realm_name, [algorithm]) do
      json(conn, %{data: keys})
    end
  end

  def get_key(conn, %{
        "realm_name" => realm_name,
        "key_algorithm" => key_algorithm,
        "key_name" => key_name
      }) do
    with {:ok, algorithm_atom} <- Secrets.Core.string_to_key_type(key_algorithm),
         {:ok, key} <- Secrets.Core.find_key(realm_name, key_name, algorithm_atom) do
      json(conn, %{data: %{key_name: key.name, public_key: key.public_pem}})
    else
      :error ->
        {:error, :unprocessable_key}

      :not_found ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Key not found"}})
    end
  end
end
