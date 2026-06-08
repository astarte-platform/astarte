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

defmodule Astarte.RealmManagementWeb.ApiSpec do
  @moduledoc false
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{
    Components,
    Contact,
    Header,
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

  alias Astarte.RealmManagementWeb.ApiSpec.Schemas.{
    AuthConfig,
    DataSimpleTrigger,
    DatastreamMaximumStorageRetention,
    DeviceRegistrationLimit,
    DeviceSimpleTrigger,
    Errors,
    HTTPPostAction,
    Interface,
    Mapping,
    TriggerConfig,
    TriggerDeliveryPolicyConfig,
    TriggerDeliveryPolicyErrorHandler
  }

  alias Astarte.RealmManagementWeb.Router

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      # Populate the Server info from a phoenix endpoint
      servers: [
        %Server{
          url: "{base_url}/v1",
          variables: %{
            base_url: %ServerVariable{
              default: "http://localhost:4000",
              description: """
              The base URL you're serving Astarte from. This should point to the base path from which Realm Management is served.
              In case you are running a local installation, this is likely `http://localhost:4000`.
              In case you have a standard Astarte installation, it is most likely `https://<your host>/realmmanagement`.
              """
            }
          }
        }
      ],
      info: %Info{
        title: to_string(Application.spec(:astarte_realm_management, :description)),
        version: to_string(Application.spec(:astarte_realm_management, :vsn)),
        description: """
        Astarte's Realm Management is the main mechanism to configure a Realm.
        It allows installing and managing Interfaces, Triggers and any configuration
        of the Realm itself.
        """,
        contact: %Contact{email: "info@ispirata.com"}
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
          name: "config",
          description:
            "Realm Configuration Management. These APIs configure the global behavior of the Realm and how it can be accessed."
        },
        %Tag{
          name: "interface",
          description:
            "Interface management. These APIs are used for installing, deleting (if possible) and updating Interfaces in a Realm.",
          externalDocs: %{
            description: "User documentation",
            url: "https://docs.astarte-platform.org/astarte/1.0/030-manage_interfaces.html"
          }
        },
        %Tag{
          name: "trigger",
          description: "Trigger management",
          externalDocs: %{
            description: "User documentation",
            url: "https://docs.astarte-platform.org/astarte/1.0/060-triggers.html"
          }
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
      "AuthConfig" => AuthConfig.schema(),
      "DeviceRegistrationLimit" => DeviceRegistrationLimit.schema(),
      "DatastreamMaximumStorageRetention" => DatastreamMaximumStorageRetention.schema(),
      "Interface" => Interface.schema(),
      "Mapping" => Mapping.schema(),
      "TriggerConfig" => TriggerConfig.schema(),
      "TriggerDeliveryPolicyConfig" => TriggerDeliveryPolicyConfig.schema(),
      "TriggerDeliveryPolicyErrorHandler" => TriggerDeliveryPolicyErrorHandler.schema(),
      "HTTPPostAction" => HTTPPostAction.schema(),
      "DataSimpleTrigger" => DataSimpleTrigger.schema(),
      "DeviceSimpleTrigger" => DeviceSimpleTrigger.schema(),
      "GenericError" => Errors.GenericError.schema(),
      "ValidationError" => Errors.ValidationError.schema(),
      "MissingTokenError" => Errors.MissingTokenError.schema(),
      "InvalidTokenError" => Errors.InvalidTokenError.schema(),
      "InvalidAuthPathError" => Errors.InvalidAuthPathError.schema(),
      "AuthorizationPathNotMatchedError" => Errors.AuthorizationPathNotMatchedError.schema()
    }
  end

  defp component_request_bodies do
    %{
      "InstallTrigger" => install_trigger_request_body(),
      "InstallTriggerDeliveryPolicy" => install_trigger_delivery_policy_request_body(),
      "InstallInterface" => install_interface_request_body(),
      "PutAuthConfig" => put_auth_config_request_body(),
      "UpdateInterface" => update_interface_request_body()
    }
  end

  defp install_trigger_request_body do
    %RequestBody{
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            type: :object,
            required: [:data],
            properties: %{
              data: %Reference{"$ref": "#/components/schemas/TriggerConfig"}
            }
          }
        }
      }
    }
  end

  defp install_trigger_delivery_policy_request_body do
    %RequestBody{
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            type: :object,
            required: [:data],
            properties: %{
              data: %Reference{"$ref": "#/components/schemas/TriggerDeliveryPolicyConfig"}
            }
          }
        }
      }
    }
  end

  defp install_interface_request_body do
    %RequestBody{
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            type: :object,
            required: [:data],
            properties: %{
              data: %Reference{"$ref": "#/components/schemas/Interface"}
            }
          }
        }
      },
      required: true,
      description: "A JSON object representing an Astarte Interface."
    }
  end

  defp put_auth_config_request_body do
    %RequestBody{
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            type: :object,
            required: [:data],
            properties: %{
              data: %Reference{"$ref": "#/components/schemas/AuthConfig"}
            }
          }
        }
      },
      required: true,
      description: "AuthConfig object with the new configuration"
    }
  end

  defp update_interface_request_body do
    %RequestBody{
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            type: :object,
            required: [:data],
            properties: %{
              data: %Reference{"$ref": "#/components/schemas/Interface"}
            }
          },
          example: %{
            data: %{
              "interface_name" => "org.astarteplatform.Values",
              "version_major" => 0,
              "version_minor" => 2,
              "type" => "datastream",
              "ownership" => "device",
              "mappings" => [
                %{
                  endpoint: "/realValue",
                  type: "double",
                  explicit_timestamp: true
                },
                %{
                  endpoint: "/anotherValue",
                  type: "string"
                }
              ]
            }
          }
        }
      },
      required: true,
      description: "A JSON object representing the updated Astarte Interface."
    }
  end

  defp component_responses do
    %{
      "ConfigValidationError" => config_validation_error_response(),
      "Forbidden" => forbidden_response(),
      "GetAuthConfig" => get_auth_config_response(),
      "GetDeviceRegistrationLimit" => get_device_registration_limit_response(),
      "GetDatastreamMaximumStorageRetention" =>
        get_datastream_maximum_storage_retention_response(),
      "GetInterface" => get_interface_response(),
      "GetInterfaceList" => get_interface_list_response(),
      "GetInterfaceMajorVersions" => get_interface_major_versions_response(),
      "GetTrigger" => get_trigger_response(),
      "GetTriggerDeliveryPolicy" => get_trigger_delivery_policy_response(),
      "GetTriggerList" => get_trigger_list_response(),
      "GetTriggerDeliveryPolicyList" => get_trigger_delivery_policy_list_response(),
      "InstallInterface" => install_interface_response(),
      "InstallTrigger" => install_trigger_response(),
      "InstallTriggerDeliveryPolicy" => install_trigger_delivery_policy_response(),
      "InterfaceNotFound" => interface_not_found_response(),
      "InterfaceValidationError" => interface_validation_error_response(),
      "TriggerNotFound" => trigger_not_found_response(),
      "TriggerValidationError" => trigger_validation_error_response(),
      "TriggerDeliveryPolicyAlreadyInstalledError" =>
        trigger_delivery_policy_already_installed_error_response(),
      "TriggerDeliveryPolicyCurrentlyUsedError" =>
        trigger_delivery_policy_currently_used_error_response(),
      "TriggerDeliveryPolicyValidationError" =>
        trigger_delivery_policy_validation_error_response(),
      "TriggerDeliveryPolicyNotFound" => trigger_delivery_policy_not_found_response(),
      "Unauthorized" => unauthorized_response(),
      "AuthorizationPathNotMatched" => authorization_path_not_matched_response(),
      "UpdateConflict" => update_conflict_response(),
      "InternalServerError" => internal_server_error_response(),
      "NotFound" => not_found_response()
    }
  end

  defp component_parameters do
    %{
      "Realm" => %Parameter{
        name: :realm_name,
        in: :path,
        description: "Target realm.",
        required: true,
        schema: %Schema{type: :string}
      },
      "DeviceID" => %Parameter{
        name: :device_id,
        in: :path,
        description: "Device ID",
        required: true,
        schema: %Schema{type: :string}
      },
      "InterfaceName" => %Parameter{
        name: :interface_name,
        in: :path,
        description: "Interface name",
        required: true,
        schema: %Schema{type: :string}
      },
      "InterfaceMajor" => %Parameter{
        name: :major_version,
        in: :path,
        description: "Interface major version",
        required: true,
        schema: %Schema{type: :integer}
      },
      "TriggerName" => %Parameter{
        name: :trigger_name,
        in: :path,
        description: "Trigger name",
        required: true,
        schema: %Schema{type: :string}
      },
      "TriggerDeliveryPolicyName" => %Parameter{
        name: :policy_name,
        in: :path,
        description: "Trigger delivery policy name",
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

  defp unauthorized_response do
    %Response{
      description: "Token/Realm doesn't exist or operation not allowed.",
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            oneOf: [
              schema_ref("MissingTokenError"),
              schema_ref("InvalidTokenError"),
              schema_ref("InvalidAuthPathError")
            ]
          }
        }
      }
    }
  end

  defp config_validation_error_response do
    validation_error_response(
      "The provided configuration is not valid.",
      %{errors: %{jwt_public_key_pem: ["is not a valid PEM public key"]}}
    )
  end

  defp forbidden_response do
    json_response(
      "Authorization failed for the resource. This could also result from unexisting resources.",
      %Schema{
        oneOf: [schema_ref("AuthorizationPathNotMatchedError"), schema_ref("GenericError")]
      },
      example: %{errors: %{detail: "Forbidden"}}
    )
  end

  defp get_auth_config_response do
    data_response("Success", "AuthConfig")
  end

  defp get_device_registration_limit_response do
    data_response("Success", "DeviceRegistrationLimit")
  end

  defp get_datastream_maximum_storage_retention_response do
    data_response("Success", "DatastreamMaximumStorageRetention")
  end

  defp get_interface_response do
    data_response("Success", "Interface")
  end

  defp get_interface_list_response do
    list_data_response(
      "Success",
      %Schema{type: :string},
      %{data: ["com.example.InterfaceFoo", "com.example.InterfaceBar"]}
    )
  end

  defp get_interface_major_versions_response do
    list_data_response("Success", %Schema{type: :integer}, %{data: [1, 2, 10]})
  end

  defp get_trigger_response do
    json_response(
      "Success",
      %Schema{
        type: :string,
        properties: %{data: schema_ref("TriggerConfig")}
      },
      example: %{
        data: %{
          name: "my_device_connected",
          action: %{http_post_url: "http://example.com/my_post_url"},
          simple_triggers: [
            %{
              "on" => "device_connected",
              type: "device_trigger",
              device_id: "glO6LullTKmwxebForU-eg"
            }
          ]
        }
      }
    )
  end

  defp get_trigger_delivery_policy_response do
    json_response(
      "Success",
      %Schema{
        type: :string,
        properties: %{data: schema_ref("TriggerDeliveryPolicyConfig")}
      },
      example: %{
        data: %{
          name: "my_policy",
          maximum_capacity: 100,
          error_handlers: [
            %{
              "on" => "any_error",
              strategy: "discard"
            }
          ]
        }
      }
    )
  end

  defp get_trigger_list_response do
    list_data_response(
      "Success",
      %Schema{type: :string},
      %{data: ["new_data_on_test_interface", "connected_device", "value_above_threshold_alarm"]}
    )
  end

  defp get_trigger_delivery_policy_list_response do
    list_data_response(
      "Success",
      %Schema{type: :string},
      %{
        data: [
          "retry_on_all_errors_policy",
          "simple_policy",
          "discard_403_errors_policy"
        ]
      }
    )
  end

  defp install_interface_response do
    location_header_response(
      "Interface installation successfully started",
      "URL of the installed interface"
    )
  end

  defp install_trigger_response do
    data_response(
      "Success",
      "TriggerConfig",
      headers: location_header("URL of the installed trigger")
    )
  end

  defp install_trigger_delivery_policy_response do
    data_response(
      "Success",
      "TriggerDeliveryPolicyConfig",
      headers: location_header("URL of the installed trigger delivery policy")
    )
  end

  defp interface_not_found_response do
    generic_error_response("Requested interface was not found", "Interface not found")
  end

  defp interface_validation_error_response do
    validation_error_response(
      "The provided interface is not valid.",
      %{errors: %{mappings: %{type: ["is invalid"]}}}
    )
  end

  defp trigger_not_found_response do
    generic_error_response("Requested trigger was not found", "Trigger not found")
  end

  defp trigger_validation_error_response do
    validation_error_response(
      "The provided trigger configuration is not valid.",
      %{errors: %{simple_triggers: [%{device_id: ["is not a valid device_id"]}]}}
    )
  end

  defp trigger_delivery_policy_already_installed_error_response do
    generic_error_response(
      "A trigger delivery policy with this name already exists.",
      "Policy already exists"
    )
  end

  defp trigger_delivery_policy_currently_used_error_response do
    generic_error_response(
      "The trigger delivery policy to delete is linked to one or more triggers.",
      "Cannot delete policy as it is being currently used by triggers"
    )
  end

  defp trigger_delivery_policy_validation_error_response do
    validation_error_response(
      "The provided trigger delivery policy is not valid.",
      %{errors: %{detail: "is invalid"}}
    )
  end

  defp trigger_delivery_policy_not_found_response do
    generic_error_response(
      "Requested trigger delivery policy was not found",
      "Trigger policy not found"
    )
  end

  defp authorization_path_not_matched_response do
    object_response("Authorization path not matched.", %{
      data: %Reference{"$ref": "#/components/schemas/AuthorizationPathNotMatchedError"}
    })
  end

  defp update_conflict_response do
    generic_error_response(
      "The updated interface is valid, but there's a conflict with the existing one",
      "Interface minor version was not increased"
    )
  end

  defp internal_server_error_response do
    json_response("Internal Server Error.", schema_ref("GenericError"))
  end

  defp not_found_response do
    json_response("Resource not found.", schema_ref("GenericError"))
  end

  defp object_response(description, properties) do
    schema_response(description, %Schema{type: :object, properties: properties})
  end

  defp data_response(description, schema_name, opts \\ []) do
    json_response(
      description,
      %Schema{
        type: :object,
        required: [:data],
        properties: %{data: schema_ref(schema_name)}
      },
      opts
    )
  end

  defp list_data_response(description, items_schema, example) do
    json_response(
      description,
      %Schema{
        type: :object,
        required: [:data],
        properties: %{
          data: %Schema{
            type: :array,
            items: items_schema
          }
        }
      },
      example: example
    )
  end

  defp generic_error_response(description, detail) do
    json_response(description, schema_ref("GenericError"), example: %{errors: %{detail: detail}})
  end

  defp validation_error_response(description, example) do
    json_response(description, schema_ref("ValidationError"), example: example)
  end

  defp location_header_response(description, location_description) do
    %Response{
      description: description,
      headers: location_header(location_description)
    }
  end

  defp location_header(description) do
    %{
      "Location" => %Header{
        description: description,
        schema: %Schema{type: :string}
      }
    }
  end

  defp schema_ref(name) do
    %Reference{"$ref": "#/components/schemas/#{name}"}
  end

  defp schema_response(description, schema) do
    json_response(description, schema)
  end

  defp json_response(description, schema, opts \\ []) do
    media_type = %MediaType{schema: schema, example: Keyword.get(opts, :example)}

    %Response{
      description: description,
      headers: Keyword.get(opts, :headers),
      content: %{
        "application/json" => media_type
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
