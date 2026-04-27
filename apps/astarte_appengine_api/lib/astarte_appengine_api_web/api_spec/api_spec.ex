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

defmodule Astarte.AppEngine.APIWeb.ApiSpec do
  @moduledoc false
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{
    Components,
    Contact,
    ExternalDocumentation,
    Info,
    MediaType,
    OpenApi,
    Parameter,
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

  alias Astarte.AppEngine.APIWeb.ApiSpec.Schemas.DeviceStatus
  alias Astarte.AppEngine.APIWeb.ApiSpec.Schemas.Errors
  alias Astarte.AppEngine.APIWeb.Router

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      # Populate the Server info from a phoenix endpoint
      servers: [
        %Server{
          url: "{base_url}/v1",
          variables: %{
            base_url: %ServerVariable{
              default: "http://localhost:4002",
              description: """
              The base URL you're serving Astarte from. This should point to the base path from which AppEngine API is served.
              In case you are running a local installation, this is likely `http://localhost:4002`.
              In case you have a standard Astarte installation, it is most likely `https://<your host>/appengine`.
              """
            }
          }
        }
      ],
      info: %Info{
        title: to_string(Application.spec(:astarte_appengine_api, :description)),
        version: to_string(Application.spec(:astarte_appengine_api, :vsn)),
        description: """
        Astarte's AppEngine API is the main entry point for any operations which have
        an impact on devices and their data. Most Astarte applications would want to
        use this API to interact with devices, stream and receive data, and oversee
        their fleet.
        """,
        contact: %Contact{email: "info@ispirata.com"}
      },
      externalDocs: %ExternalDocumentation{
        description: "User documentation",
        url: "https://docs.astarte-platform.org/astarte/1.0/050-query_device.html"
      },
      # Populate the paths from a phoenix router
      paths: Router |> Paths.from_router() |> strip_path_prefix("/v1"),
      components: %Components{
        schemas: component_schemas(),
        requestBodies: component_request_bodies(),
        responses: component_responses(),
        parameters: component_parameters(),
        securitySchemes: component_security_schemes()
      },
      tags: [
        %Tag{
          name: "device",
          description:
            "Device data status retrieval and publish. All operations on a device can be done using both the device id or any of its aliases."
        },
        %Tag{
          name: "groups",
          description:
            "Manage groups creation, allowing to create a new group, add or remove devices from it and query devices that belong to it."
        },
        %Tag{
          name: "stats",
          description: "Retrieve stats (e.g. total number of devices, connected devices, etc)."
        },
        %Tag{
          name: "version",
          description: "Retrieve version information of the API."
        }
      ]
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
    |> drop_empty_callbacks()
  end

  defp component_schemas do
    %{
      "DeviceStatus" => DeviceStatus.schema(),
      "CreateGroupConfig" => create_group_config_schema(),
      "GroupConfig" => group_config_schema(),
      "DevicesStats" => devices_stats_schema(),
      "NotFoundError" => Errors.NotFoundError.schema(),
      "MissingTokenError" => Errors.MissingTokenError.schema(),
      "InvalidTokenError" => Errors.InvalidTokenError.schema(),
      "InvalidAuthPathError" => Errors.InvalidAuthPathError.schema(),
      "AuthorizationPathNotMatchedError" => Errors.AuthorizationPathNotMatchedError.schema(),
      "UnauthorizedError" => Errors.UnauthorizedError.schema(),
      "GroupNotFoundError" => Errors.GroupNotFoundError.schema(),
      "GroupOrDeviceNotFoundError" => Errors.GroupOrDeviceNotFoundError.schema()
    }
  end

  defp component_request_bodies do
    %{
      "AddDeviceToGroup" => add_device_to_group_request_body(),
      "CreateGroup" => create_group_request_body()
    }
  end

  defp component_responses do
    %{
      "IndexGroups" => index_groups_response(),
      "GetGroup" => get_group_response(),
      "GroupCreated" => group_created_response(),
      "IndexGroupDevices" => index_group_devices_response(),
      "InvalidAddGroup" => invalid_add_group_response(),
      "InvalidGroupConfig" => invalid_group_config_response(),
      "Unauthorized" => unauthorized_response(),
      "AuthorizationPathNotMatched" => authorization_path_not_matched_response(),
      "GroupNotFound" => group_not_found_response(),
      "GroupOrDeviceNotFound" => group_or_device_not_found_response(),
      "GetDevicesStats" => get_devices_stats_response()
    }
  end

  defp component_parameters do
    %{
      "GroupName" => %Parameter{
        name: :group_name,
        in: :path,
        description: "The name of the group.",
        required: true,
        schema: %Schema{type: :string}
      },
      "RealmName" => %Parameter{
        name: :realm_name,
        in: :path,
        description: "The name of the realm the device list will be returned from.",
        required: true,
        schema: %Schema{type: :string}
      },
      "DeviceId" => %Parameter{
        name: :device_id,
        in: :path,
        description: "Device id of the target device.",
        required: true,
        schema: %Schema{type: :string}
      }
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
        the private key associated with the realm the request refers to.


        The following syntax must be used in the `Authorization` header :
        `Bearer xxxxxx.yyyyyyy.zzzzzz`
        """
      }
    }
  end

  defp create_group_config_schema do
    %Schema{
      type: :object,
      required: [:group_name, :devices],
      properties: %{
        group_name: %Schema{type: :string, example: "mygroupname"},
        devices: %Schema{
          type: :array,
          items: %Schema{type: :string},
          example: ["v8UxxIT9RkyPjIJZt6-Rrw", "fhd0WHcgSjWeVqPGKZv_KA"]
        }
      }
    }
  end

  defp group_config_schema do
    %Schema{
      type: :object,
      properties: %{
        group_name: %Schema{type: :string, example: "mygroupname"}
      }
    }
  end

  defp devices_stats_schema do
    %Schema{
      type: :object,
      properties: %{
        total_devices: %Schema{
          description: "The total number of devices in the Realm",
          type: :integer,
          example: 203
        },
        connected_devices: %Schema{
          description: "The number of devices currently connected in the Realm",
          type: :integer,
          example: 30
        }
      }
    }
  end

  defp add_device_to_group_request_body do
    %RequestBody{
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            type: :object,
            required: [:data],
            properties: %{
              data: %Schema{
                type: :object,
                required: [:device_id],
                properties: %{
                  device_id: %Schema{
                    description: "The device id of the device to add",
                    type: :string,
                    example: "8NWCESshRrmUe9FWhg39qQ"
                  }
                }
              }
            }
          }
        }
      }
    }
  end

  defp create_group_request_body do
    %RequestBody{
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            type: :object,
            required: [:data],
            properties: %{
              data: %Reference{"$ref": "#/components/schemas/CreateGroupConfig"}
            }
          }
        }
      }
    }
  end

  defp index_groups_response do
    object_response("Groups list", %{
      data: %Schema{
        type: :array,
        description: "Group name list",
        items: %Schema{type: :string},
        example: ["first-floor", "second-floor"]
      }
    })
  end

  defp get_group_response do
    object_response("Groups list", %{
      data: %Reference{"$ref": "#/components/schemas/GroupConfig"}
    })
  end

  defp group_created_response do
    object_response("Success", %{
      data: %Reference{"$ref": "#/components/schemas/CreateGroupConfig"}
    })
  end

  defp index_group_devices_response do
    object_response("Group device list", %{
      data: %Schema{
        type: :array,
        items: %Schema{type: :string},
        example: ["v8UxxIT9RkyPjIJZt6-Rrw", "fhd0WHcgSjWeVqPGKZv_KA"]
      }
    })
  end

  defp invalid_add_group_response do
    object_response("Invalid request", %{
      errors: %Schema{
        type: :object,
        properties: %{
          device_id: %Schema{
            type: :array,
            items: %Schema{type: :string}
          }
        },
        example: %{
          device_id: ["does not exist"]
        }
      }
    })
  end

  defp invalid_group_config_response do
    object_response("Invalid group configuration", %{
      errors: %Schema{
        type: :object,
        properties: %{
          group_name: %Schema{
            type: :array,
            items: %Schema{type: :string}
          },
          devices: %Schema{
            type: :array,
            items: %Schema{type: :string}
          }
        },
        example: %{
          group_name: ["is invalid"]
        }
      }
    })
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
              Errors.InvalidAuthPathError,
              Errors.UnauthorizedError
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

  defp group_not_found_response do
    schema_response("Group not found", Errors.GroupNotFoundError)
  end

  defp group_or_device_not_found_response do
    schema_response("Group or device not found", Errors.GroupOrDeviceNotFoundError)
  end

  defp get_devices_stats_response do
    object_response("Devices stats", %{
      data: %Reference{"$ref": "#/components/schemas/DevicesStats"}
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
        |> normalize_wildcard_path()

      {path, path_item}
    end)
    |> Map.new()
  end

  defp normalize_wildcard_path(path) do
    String.replace(path, "/*path_tokens", "/{path}")
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
