#
# This file is part of Astarte.
#
# Copyright 2017 - 2026 Seco Mind Srl
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

defmodule Astarte.PairingWeb.AgentController do
  use Astarte.PairingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.Pairing.Agent
  alias Astarte.Pairing.Agent.DeviceRegistrationResponse
  alias Astarte.PairingWeb.ApiSpec.Schemas.Agent, as: AgentSpec
  alias Astarte.PairingWeb.ApiSpec.Schemas.Errors
  alias OpenApiSpex.{MediaType, Reference, Response, Schema}

  action_fallback Astarte.PairingWeb.FallbackController

  tags ["agent"]
  security [%{"JWT" => []}]

  operation :create,
    summary: "Register a device",
    operation_id: "registerDevice",
    description: """
    Register a device, obtaining its credentials secret. The registration
    can be repeated as long as the device didn't request any credentials.
    An optional initial introspection for the device can be passed in the
    registration request.
    """,
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ]
    ],
    request_body: {
      "Device parameters",
      "application/json",
      AgentSpec.DeviceRegistrationRequest,
      required: true
    },
    responses: [
      created: {"Device registered", "application/json", AgentSpec.DeviceRegistrationResponse},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Response{
        description: "Forbidden or Authorization path not matched",
        content: %{
          "application/json" => %MediaType{
            schema: %Schema{
              oneOf: [
                Errors.ForbiddenResponse,
                Errors.AuthorizationPathNotMatchedResponse
              ]
            }
          }
        }
      },
      unprocessable_entity: %Response{
        description: "Unprocessable entity",
        content: %{
          "application/json" => %MediaType{
            schema: Errors.GenericErrorResponse,
            example: %{
              errors: %{
                hw_id: ["can't be blank"]
              }
            }
          }
        }
      }
    ]

  operation :delete,
    summary: "Unregister a device",
    operation_id: "unregisterDevice",
    description:
      "Unregister a device. This makes it possible to register it again, even if it already has requested its credentials. All data belonging to the device will be kept as is.",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ],
      device_id: [
        in: :path,
        description: "The Device ID of the device that will be unregistered.",
        type: :string,
        required: true
      ]
    ],
    responses: [
      no_content: {"Device unregistered", nil, nil},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Response{
        description: "Forbidden or Authorization path not matched",
        content: %{
          "application/json" => %MediaType{
            schema: %Schema{
              oneOf: [
                Errors.ForbiddenResponse,
                Errors.AuthorizationPathNotMatchedResponse
              ]
            }
          }
        }
      },
      not_found: %Response{
        description: "Device not found",
        content: %{
          "application/json" => %MediaType{
            schema: Errors.GenericErrorResponse,
            example: %{
              errors: %{
                detail: "Device not found"
              }
            }
          }
        }
      }
    ]

  def create(conn, %{"realm_name" => realm, "data" => params}) do
    with {:ok, %DeviceRegistrationResponse{} = response} <- Agent.register_device(realm, params) do
      conn
      |> put_status(:created)
      |> render("show.json", device_registration_response: response)
    end
  end

  def delete(conn, %{"realm_name" => realm, "device_id" => device_id}) do
    :telemetry.execute([:astarte, :pairing, :unregister_device], %{}, %{realm: realm})

    with :ok <- Agent.unregister_device(realm, device_id) do
      conn
      |> resp(:no_content, "")
    end
  end
end
