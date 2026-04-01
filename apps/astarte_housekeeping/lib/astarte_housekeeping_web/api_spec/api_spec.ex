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

defmodule Astarte.HousekeepingWeb.ApiSpec do
  @moduledoc false
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{
    Components,
    Contact,
    Info,
    MediaType,
    OpenApi,
    Paths,
    Reference,
    RequestBody,
    Response,
    Schema,
    SecurityScheme,
    Server,
    ServerVariable,
    Tag
  }

  alias Astarte.HousekeepingWeb.ApiSpec.Schemas.Errors
  alias Astarte.HousekeepingWeb.ApiSpec.Schemas.Realm
  alias Astarte.HousekeepingWeb.Router

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      # Populate the Server info from a phoenix endpoint
      servers: [
        %Server{
          url: "{base_url}/v1",
          variables: %{
            base_url: %ServerVariable{
              default: "http://localhost:4001",
              description: """
              The base URL you're serving Astarte from. This should point to the base path from which Housekeeping is served.
              In case you are running a local installation, this is likely `http://localhost:4001`.
              In case you have a standard Astarte installation, it is most likely `https://<your host>/housekeeping`.
              """
            }
          }
        }
      ],
      info: %Info{
        title: to_string(Application.spec(:astarte_housekeeping, :description)),
        version: to_string(Application.spec(:astarte_housekeeping, :vsn)),
        description: """
        APIs for Administration activities such as Realm creation and Astarte configuration.
        This API is usually accessible only to system administrators, and is not meant for the average user of Astarte,
        which should refer to Realm Management API instead.
        """,
        contact: %Contact{email: "info@ispirata.com"}
      },
      # Populate the paths from a phoenix router
      paths: Router |> Paths.from_router() |> strip_path_prefix("/v1"),
      components: %Components{
        schemas: component_schemas(),
        requestBodies: component_request_bodies(),
        responses: component_responses(),
        securitySchemes: component_security_schemes()
      },
      tags: [
        %Tag{
          name: "realm",
          description: "APIs for managing Realms."
        }
      ]
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
    |> drop_empty_callbacks()
  end

  defp component_schemas do
    %{
      "Realm" => Realm.Realm.schema(),
      "RealmPatch" => Realm.RealmPatch.schema(),
      "GenericError" => Errors.GenericError.schema(),
      "MissingTokenError" => Errors.MissingTokenError.schema(),
      "InvalidTokenError" => Errors.InvalidTokenError.schema(),
      "InvalidAuthPathError" => Errors.InvalidAuthPathError.schema(),
      "AuthorizationPathNotMatchedError" => Errors.AuthorizationPathNotMatchedError.schema()
    }
  end

  defp component_request_bodies do
    %{
      "createRealmBody" => create_realm_request_body(),
      "updateRealmBody" => update_realm_request_body()
    }
  end

  defp create_realm_request_body do
    %RequestBody{
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            properties: %{
              data: %Reference{"$ref": "#/components/schemas/Realm"}
            }
          }
        }
      },
      required: true,
      description: "Realm JSON configuration object."
    }
  end

  defp update_realm_request_body do
    %RequestBody{
      content: %{
        "application/merge-patch+json" => %MediaType{
          schema: %Schema{
            type: :object,
            properties: %{
              data: %Reference{"$ref": "#/components/schemas/RealmPatch"}
            }
          }
        }
      },
      required: true,
      description:
        "A JSON Merge Patch containing the property changes that should be applied to the realm. Explicitly set a property to null to remove it."
    }
  end

  defp component_responses do
    %{
      "Unauthorized" => unauthorized_response(),
      "AuthorizationPathNotMatched" => authorization_path_not_matched_response()
    }
  end

  defp component_security_schemes do
    %{
      "JWT" => %SecurityScheme{
        type: "apiKey",
        name: "Authorization",
        in: "header",
        description: """
        To access APIs a valid JWT token must be passed in all requests
        in the `Authorization` header. This token should be signed with
        the private key provided upon Housekeeping installation.


        The following syntax must be used in the `Authorization` header :
        `Bearer xxxxxx.yyyyyyy.zzzzzz`
        """
      }
    }
  end

  defp unauthorized_response do
    %Response{
      description: "Token/Realm doesn't exist or operation not allowed.",
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            oneOf: [
              Errors.MissingTokenError,
              Errors.InvalidTokenError,
              Errors.InvalidAuthPathError
            ]
          }
        }
      }
    }
  end

  defp authorization_path_not_matched_response do
    object_response("Authorization path not matched.", %{
      data: %Reference{"$ref": "#/components/schemas/AuthorizationPathNotMatchedError"}
    })
  end

  defp object_response(description, properties) do
    schema_response(description, %Schema{type: :object, properties: properties})
  end

  defp schema_response(description, schema) do
    %Response{
      description: description,
      content: %{
        "application/json" => %MediaType{schema: schema}
      }
    }
  end

  defp strip_path_prefix(openapi_paths, prefix) do
    openapi_paths
    |> Enum.map(fn {path, path_item} ->
      path =
        path
        |> String.replace_prefix(prefix, "")

      {path, path_item}
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
