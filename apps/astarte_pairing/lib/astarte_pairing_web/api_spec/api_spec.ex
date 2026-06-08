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

defmodule Astarte.PairingWeb.ApiSpec do
  @moduledoc false
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{
    Components,
    Contact,
    ExternalDocumentation,
    Info,
    MediaType,
    OpenApi,
    Paths,
    Response,
    Schema,
    SecurityScheme,
    Server,
    ServerVariable,
    Tag
  }

  alias Astarte.PairingWeb.ApiSpec.Schemas.Errors
  alias Astarte.PairingWeb.Router

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      # Populate the Server info from a phoenix endpoint
      servers: [
        %Server{
          url: "{base_url}/v1",
          variables: %{
            base_url: %ServerVariable{
              default: "http://localhost:4003",
              description: """
              The base URL you're serving Astarte from. This should point to the base path from which Pairing API is served.
              In case you are running a local installation, this is likely `http://localhost:4003`.
              In case you have a standard Astarte installation, it is most likely `https://<your host>/pairing`.
              """
            }
          }
        }
      ],
      info: %Info{
        title: to_string(Application.spec(:astarte_pairing, :description)),
        version: to_string(Application.spec(:astarte_pairing, :vsn)),
        description: "Control device registration, authentication and authorization",
        contact: %Contact{email: "info@ispirata.com"}
      },
      # Populate the paths from a phoenix router
      paths: Router |> Paths.from_router() |> strip_path_prefix("/v1"),
      components: %Components{
        schemas: %{
          "MissingTokenResponse" => Errors.MissingTokenResponse.schema(),
          "InvalidTokenResponse" => Errors.InvalidTokenResponse.schema(),
          "InvalidAuthPathResponse" => Errors.InvalidAuthPathResponse.schema(),
          "UnauthorizedResponse" => Errors.UnauthorizedResponse.schema(),
          "AuthorizationPathNotMatchedResponse" =>
            Errors.AuthorizationPathNotMatchedResponse.schema()
        },
        responses: %{
          "Unauthorized" => %Response{
            description: "Token/Realm doesn't exist or operation not allowed.",
            content: %{
              "application/json" => %MediaType{
                schema: %Schema{
                  oneOf: [
                    Errors.MissingTokenResponse,
                    Errors.InvalidTokenResponse,
                    Errors.InvalidAuthPathResponse,
                    Errors.UnauthorizedResponse
                  ]
                }
              }
            }
          },
          "AuthorizationPathNotMatched" => %Response{
            description: "Authorization path not matched.",
            content: %{
              "application/json" => %MediaType{
                schema: %Schema{
                  type: :object,
                  properties: %{
                    data: Errors.AuthorizationPathNotMatchedResponse
                  }
                }
              }
            }
          }
        },
        securitySchemes: %{
          "JWT" => %SecurityScheme{
            type: "apiKey",
            name: "Authorization",
            in: "header",
            description: """
            For accessing the agent API a valid JWT token must be passed in all the queries in the 'Authorization' header.
            The following syntax must be used in the 'Authorization' header : Bearer xxxxxx.yyyyyyy.zzzzzz
            """
          },
          "CredentialsSecret" => %SecurityScheme{
            type: "apiKey",
            name: "Authorization",
            in: "header",
            description: """
            For accessing the device API a valid Credentials Secret must be passed in all the queries in the 'Authorization' header.
            The following syntax must be used in the 'Authorization' header : Bearer xxxxxxxxxxxxxxxxxxxxx
            """
          },
          "FDOSessionToken" => %SecurityScheme{
            type: "apiKey",
            name: "Authorization",
            in: "header",
            description: """
            FDO session token. Must be provided in the Authorization header as a bearer token.
            The token is validated and decoded to extract the device GUID and nonce.
            Example: Authorization: Bearer <FDO-session-token>.
            Token must match the session and nonce for the device in the current realm.
            """
          }
        }
      },
      tags: [
        %Tag{
          name: "agent",
          description: "Device registration and credentials secret emission",
          externalDocs: %ExternalDocumentation{
            description: "Find out more",
            url: "https://docs.astarte-platform.org/astarte/1.0/050-pairing_mechanism.html"
          }
        },
        %Tag{
          name: "device",
          description: "Device credentials emission and info",
          externalDocs: %ExternalDocumentation{
            description: "Find out more",
            url: "https://docs.astarte-platform.org/astarte/1.0/050-pairing_mechanism.html"
          }
        },
        %Tag{
          name: "fdo",
          description: "FDO onboarding API"
        }
      ]
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
    |> drop_empty_callbacks()
  end

  defp strip_path_prefix(openapi_paths, prefix) do
    openapi_paths
    |> Enum.map(fn {path, path_item} ->
      {String.replace_prefix(path, prefix, ""), path_item}
    end)
    |> Map.new()
  end

  defp drop_empty_callbacks(%OpenApi{} = spec) do
    paths =
      spec.paths
      |> Enum.map(fn {path, path_item} ->
        {path, drop_empty_callbacks_from_path_item(path_item)}
      end)
      |> Map.new()

    %{spec | paths: paths}
  end

  defp drop_empty_callbacks_from_path_item(path_item) do
    path_item
    |> Map.from_struct()
    |> Enum.map(fn
      {method, %OpenApiSpex.Operation{callbacks: callbacks} = operation} when callbacks == %{} ->
        {method, %{operation | callbacks: nil}}

      other ->
        other
    end)
    |> then(&struct(path_item.__struct__, &1))
  end
end
