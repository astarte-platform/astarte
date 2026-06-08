#
# This file is part of Astarte.
#
# Copyright 2017 - 2026 SECO Mind Srl
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

defmodule Astarte.PairingWeb.DeviceController do
  use Astarte.PairingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Logger

  alias Astarte.Pairing.Credentials
  alias Astarte.Pairing.Credentials.AstarteMQTTV1
  alias Astarte.Pairing.Info
  alias Astarte.Pairing.Info.DeviceInfo
  alias Astarte.PairingWeb.ApiSpec.Schemas.Device
  alias Astarte.PairingWeb.ApiSpec.Schemas.Errors
  alias Astarte.PairingWeb.CredentialsStatusView
  alias Astarte.PairingWeb.CredentialsView
  alias Astarte.PairingWeb.DeviceInfoView
  alias OpenApiSpex.{Example, MediaType, Reference, Response, Schema}

  require Logger

  @bearer_regex ~r/bearer\:?\s+(.*)$/i

  action_fallback Astarte.PairingWeb.FallbackController

  tags ["device"]
  security [%{"CredentialsSecret" => []}]

  operation :show_info,
    summary: "Obtain status information for a device",
    operation_id: "getInfo",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ],
      hw_id: [
        in: :path,
        description: "Hardware id of the device.",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok:
        {"Info", "application/json",
         %Schema{
           type: :object,
           properties: %{data: Device.InfoResponse},
           required: [:data]
         }},
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
      }
    ]

  operation :create_credentials,
    summary: "Obtain the credentials for Astarte MQTT v1 protocol",
    operation_id: "obtainCredentials",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ],
      hw_id: [
        in: :path,
        description: "Hardware id of the device.",
        type: :string,
        required: true
      ],
      protocol: [
        in: :path,
        description: "Credentials protocol identifier.",
        schema: %Schema{type: :string, enum: ["astarte_mqtt_v1"]},
        required: true
      ]
    ],
    request_body: {
      "Credentials request",
      "application/json",
      %Schema{
        type: :object,
        properties: %{data: Device.AstarteMQTTV1CredentialsRequest},
        required: [:data]
      },
      required: true
    },
    responses: [
      created:
        {"Credentials created", "application/json",
         %Schema{
           type: :object,
           properties: %{data: Device.AstarteMQTTV1CredentialsResponse},
           required: [:data]
         }},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Response{
        description: "Token/Realm doesn't exist or operation not allowed.",
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
                purpose: ["can't be blank"]
              }
            }
          }
        }
      }
    ]

  operation :verify_credentials,
    summary: "Verify the credentials for Astarte MQTT v1 protocol",
    operation_id: "verifyCredentials",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ],
      hw_id: [
        in: :path,
        description: "Hardware id of the device.",
        type: :string,
        required: true
      ],
      protocol: [
        in: :path,
        description: "Credentials protocol identifier.",
        schema: %Schema{type: :string, enum: ["astarte_mqtt_v1"]},
        required: true
      ]
    ],
    request_body: {
      "Credentials verification request",
      "application/json",
      %Schema{
        type: :object,
        properties: %{data: Device.AstarteMQTTV1VerifyCredentialsRequest},
        required: [:data]
      },
      required: true
    },
    responses: [
      ok: %Response{
        description: "Credentials verified",
        content: %{
          "application/json" => %MediaType{
            schema: %Schema{
              type: :object,
              properties: %{data: Device.AstarteMQTTV1VerifyCredentialsResponse},
              required: [:data]
            },
            examples: %{
              "response valid certificate" => %Example{
                value: %{
                  data: %{
                    valid: true,
                    until: "2025-03-25 19:25:00.000Z"
                  }
                }
              },
              "response invalid certificate" => %Example{
                value: %{
                  data: %{
                    valid: false,
                    cause: "INVALID_ISSUER"
                  }
                }
              }
            }
          }
        }
      },
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Response{
        description: "Token/Realm doesn't exist or operation not allowed.",
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
                purpose: ["can't be blank"]
              }
            }
          }
        }
      }
    ]

  def create_credentials(conn, %{
        "realm_name" => realm,
        "hw_id" => hw_id,
        "protocol" => "astarte_mqtt_v1",
        "data" => params
      }) do
    alias AstarteMQTTV1.Credentials, as: AstarteCredentials

    with device_ip <- get_ip(conn),
         {:ok, secret} <- get_secret(conn),
         {:ok, %AstarteCredentials{} = credentials} <-
           Credentials.get_astarte_mqtt_v1(realm, hw_id, secret, device_ip, params) do
      resp =
        conn
        |> put_status(:created)
        |> put_view(CredentialsView)
        |> render("show_astarte_mqtt_v1.json", credentials: credentials)

      "New certificate sent to device"
      |> Logger.info(realm: realm, hw_id: hw_id)

      resp
    else
      error ->
        Logger.info("Failed to create credentials.",
          realm: realm,
          hw_id: hw_id
        )

        error
    end
  end

  def show_info(conn, %{"realm_name" => realm, "hw_id" => hw_id}) do
    with {:ok, secret} <- get_secret(conn),
         {:ok, %DeviceInfo{} = device_info} <- Info.get_device_info(realm, hw_id, secret) do
      conn
      |> put_view(DeviceInfoView)
      |> render("show.json", device_info: device_info)
    end
  end

  def verify_credentials(conn, %{
        "realm_name" => realm,
        "hw_id" => hw_id,
        "protocol" => "astarte_mqtt_v1",
        "data" => params
      }) do
    alias AstarteMQTTV1.CredentialsStatus, as: CredentialsStatus

    :telemetry.execute([:astarte, :pairing, :verify_credentials], %{}, %{realm: realm})

    with {:ok, secret} <- get_secret(conn),
         {:ok, %CredentialsStatus{} = status} <-
           Credentials.verify_astarte_mqtt_v1(realm, hw_id, secret, params) do
      conn
      |> put_view(CredentialsStatusView)
      |> render("show_astarte_mqtt_v1.json", credentials_status: status)
    end
  end

  defp get_secret(conn) do
    auth_headers = get_req_header(conn, "authorization")
    find_secret(auth_headers)
  end

  defp find_secret([]) do
    {:error, :unauthorized}
  end

  defp find_secret([auth_header | tail]) do
    case Regex.run(@bearer_regex, auth_header) do
      [_, match] ->
        {:ok, match}

      _ ->
        find_secret(tail)
    end
  end

  defp get_ip(conn) do
    conn.remote_ip
    |> :inet_parse.ntoa()
    |> to_string()
  end
end
