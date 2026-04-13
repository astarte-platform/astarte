#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.RealmManagementWeb.TriggerPolicyController do
  use Astarte.RealmManagementWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.Core.Triggers.Policy
  alias Astarte.RealmManagement.Triggers.Policies
  alias OpenApiSpex.{Reference, Schema}

  action_fallback(Astarte.RealmManagementWeb.FallbackController)

  tags ["policy"]
  security [%{"JWT" => []}]

  operation :index,
    summary: "Get trigger delivery policy list",
    description: """
    Get a list of all installed trigger delivery policies. The name for each
    installed trigger delivery policy is reported.
    """,
    operation_id: "getTriggerDeliveryPolicyList",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/GetTriggerDeliveryPolicyList"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"}
    ]

  operation :create,
    summary: "Install a trigger delivery policy configuration",
    description: """
    Install a new trigger delivery policy using provided configuration.
    Trigger Delivery Policy validation is performed before installation.
    If the trigger delivery policy configuration is not valid or a trigger
    delivery policy with the same name already exists an error is reported.
    """,
    operation_id: "installTriggerDeliveryPolicy",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"}
    ],
    request_body: {
      "Trigger delivery policy configuration",
      "application/json",
      %Schema{
        type: :object,
        required: [:data],
        properties: %{
          data: %Reference{"$ref": "#/components/schemas/TriggerDeliveryPolicyConfig"}
        }
      },
      required: true
    },
    responses: [
      created: %Reference{"$ref": "#/components/responses/InstallTriggerDeliveryPolicy"},
      bad_request: {"Bad request", nil, nil},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      conflict: %Reference{
        "$ref": "#/components/responses/TriggerDeliveryPolicyAlreadyInstalledError"
      },
      unprocessable_entity: %Reference{
        "$ref": "#/components/responses/TriggerDeliveryPolicyValidationError"
      }
    ]

  operation :show,
    summary: "Get the trigger delivery policy configuration",
    description: "Retrieve installed trigger delivery policy configuration.",
    operation_id: "getTriggerDeliveryPolicy",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"},
      %Reference{"$ref": "#/components/parameters/TriggerDeliveryPolicyName"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/GetTriggerDeliveryPolicy"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/TriggerDeliveryPolicyNotFound"},
      internal_server_error: {"Internal Server Error.", nil, nil}
    ]

  operation :delete,
    summary: "Delete trigger delivery policy",
    description: """
    Deletes the trigger delivery policy with given `policy_name`.
    An existing trigger delivery policy can be deleted only if there are no
    triggers linking to it.
    """,
    operation_id: "deleteTriggerDeliveryPolicy",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"},
      %Reference{"$ref": "#/components/parameters/TriggerDeliveryPolicyName"}
    ],
    responses: [
      no_content: {"Success", nil, nil},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/TriggerDeliveryPolicyNotFound"},
      conflict: %Reference{
        "$ref": "#/components/responses/TriggerDeliveryPolicyCurrentlyUsedError"
      },
      internal_server_error: {"Internal Server Error.", nil, nil}
    ]

  def index(conn, %{"realm_name" => realm_name}) do
    policies = Policies.list_trigger_policies(realm_name)
    render(conn, "index.json", policies: policies)
  end

  def create(conn, %{"realm_name" => realm_name, "data" => policy_params}) do
    with {:ok, %Policy{} = policy} <- Policies.create_trigger_policy(realm_name, policy_params) do
      location =
        trigger_policy_path(
          conn,
          :show,
          realm_name,
          policy.name
        )

      conn
      |> put_status(:created)
      |> put_resp_header("location", location)
      |> render("show.json", policy: policy)
    end
  end

  def show(conn, %{"realm_name" => realm_name, "policy_name" => policy_name}) do
    with {:ok, policy_source} <- Policies.get_trigger_policy_source(realm_name, policy_name),
         # Use (safe) atoms as keys to simplify handler normalization in Trigger Policy View
         # TODO: move this to a function in Astarte Core building a Policy from its source
         {:ok, decoded_json} <- Jason.decode(policy_source, keys: :atoms!) do
      render(conn, "show.json", policy: decoded_json)
    end
  end

  def delete(conn, %{"realm_name" => realm_name, "policy_name" => policy_name} = params) do
    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    with {:ok, _policy_source} <- Policies.get_trigger_policy_source(realm_name, policy_name),
         :ok <- Policies.delete_trigger_policy(realm_name, policy_name, async: async_operation) do
      send_resp(conn, :no_content, "")
    end
  end
end
