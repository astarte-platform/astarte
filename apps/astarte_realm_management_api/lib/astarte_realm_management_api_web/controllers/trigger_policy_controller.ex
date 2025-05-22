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

defmodule Astarte.RealmManagement.APIWeb.TriggerPolicyController do
  use Astarte.RealmManagement.APIWeb, :controller

  alias Astarte.RealmManagement.API.Triggers.Policies
  alias Astarte.Core.Triggers.Policy

  action_fallback(Astarte.RealmManagement.APIWeb.FallbackController)

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

  def show(conn, %{"realm_name" => realm_name, "id" => id}) do
    with {:ok, policy_source} <- Policies.get_trigger_policy_source(realm_name, id),
         # Use (safe) atoms as keys to simplify handler normalization in Trigger Policy View
         # TODO: move this to a function in Astarte Core building a Policy from its source
         {:ok, decoded_json} <- Jason.decode(policy_source, keys: :atoms!) do
      render(conn, "show.json", policy: decoded_json)
    end
  end

  def delete(conn, %{"realm_name" => realm_name, "id" => id}) do
    with {:ok, _policy_source} <- Policies.get_trigger_policy_source(realm_name, id),
         {:ok, _status} <- Policies.delete_trigger_policy(realm_name, id) do
      send_resp(conn, :no_content, "")
    end
  end
end
