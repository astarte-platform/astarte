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

defmodule Astarte.RealmManagement.API.Triggers.Policies do
  alias Astarte.Core.Triggers.Policy
  alias Astarte.RealmManagement.API.RPC.RealmManagement
  alias Astarte.RealmManagement.API.Triggers.Policies.Queries
  alias Astarte.RealmManagement.API.Triggers.Queries, as: TriggerQueries
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto

  @doc """
  Returns the list of trigger policies. Returns either `{:ok, list}` or an `{:error, reason}` tuple.
  """
  def list_trigger_policies(realm_name) do
    with {:ok, policies_list} <- Queries.get_trigger_policies_list(realm_name) do
      policies_list
    end
  end

  @doc """
  Gets a JSON-formatted trigger policy. Returns either `{:ok, string}` or an `{:error, reason}` tuple.

  ## Examples

      iex> get_trigger_policy_source(realm, trigger_policy)
      {:ok, "{name: trigger_policy}"}

      iex> get_trigger_policy_source(realm, missing_trigger_policy)
      {:error, :trigger_policy_not_found}

  """
  def get_trigger_policy_source(realm_name, policy_name) do
    with {:ok, policy_proto} <- TriggerQueries.fetch_trigger_policy(realm_name, policy_name) do
      policy_proto
      |> PolicyProto.decode()
      |> Policy.from_policy_proto!()
      |> Jason.encode()
    end
  end

  @doc """
  Creates a trigger policy. Returns either `{:ok, policy}` or an `{:error, reason}` tuple.

  ## Examples

      iex> create_trigger_policy(%{field: value})
      {:ok, %Policy{}}

      iex> create_trigger_policy(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_trigger_policy(realm_name, params) do
    changeset = Policy.changeset(%Policy{}, params)

    with {:ok, %Policy{} = policy} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, policy_source} <- Jason.encode(policy),
         {:ok, :started} <- RealmManagement.install_trigger_policy(realm_name, policy_source) do
      {:ok, policy}
    end
  end

  @doc """
  Deletes a Trigger policy. Returns either `{:ok, policy}` or an `{:error, reason}` tuple.

  ## Examples

      iex> delete_trigger_policy(trigger_policy)
      {:ok, %Policy{}}

      iex> delete_trigger_policy(trigger_policy)
      {:error, :trigger_policy_not_found}

  """
  def delete_trigger_policy(realm_name, policy_name, _attrs \\ %{}) do
    RealmManagement.delete_trigger_policy(realm_name, policy_name)
  end
end
