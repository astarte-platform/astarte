#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.RealmManagementWeb.GraphQL.Resolvers.TriggerResolver do
  @moduledoc false
  alias Astarte.RealmManagement.Triggers
  alias Astarte.RealmManagement.Triggers.Policies

  # Triggers

  def list_triggers(_parent, _args, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    case Triggers.list_triggers(realm_name) do
      triggers when is_list(triggers) -> {:ok, triggers}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def list_triggers(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def get_trigger(_parent, %{trigger_name: name}, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    case Triggers.get_trigger(realm_name, name) do
      {:ok, trigger} -> {:ok, format_trigger(trigger)}
      {:error, :cannot_retrieve_simple_trigger} -> {:error, "Internal Server Error"}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def get_trigger(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def install_trigger(_parent, %{data: data}, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    case Triggers.create_trigger(realm_name, data) do
      {:ok, trigger} -> {:ok, format_trigger(trigger)}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def install_trigger(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def delete_trigger(_parent, %{trigger_name: name}, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    with {:ok, trigger} <- Triggers.get_trigger(realm_name, name),
         {:ok, _trigger} <- Triggers.delete_trigger(realm_name, trigger) do
      {:ok, "Trigger deleted successfully"}
    else
      {:error, :cannot_delete_simple_trigger} -> {:error, "Internal Server Error"}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def delete_trigger(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  # Policies

  def list_policies(_parent, _args, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    case Policies.list_trigger_policies(realm_name) do
      policies when is_list(policies) -> {:ok, policies}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def list_policies(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def get_policy(_parent, %{policy_name: name}, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    case Policies.get_trigger_policy_source(realm_name, name) do
      {:ok, policy_source} ->
        case Jason.decode(policy_source) do
          {:ok, decoded_json} -> {:ok, decoded_json}
          _ -> {:error, "Failed to decode policy"}
        end

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  def get_policy(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def install_policy(_parent, %{data: data}, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    case Policies.create_trigger_policy(realm_name, data) do
      {:ok, policy} -> {:ok, format_policy(policy)}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def install_policy(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  def delete_policy(_parent, %{policy_name: name} = args, %{context: %{realm_name: realm_name}})
      when is_binary(realm_name) do
    async = Map.get(args, :async_operation, true)

    with {:ok, _policy_source} <- Policies.get_trigger_policy_source(realm_name, name),
         :ok <- Policies.delete_trigger_policy(realm_name, name, async: async) do
      {:ok, "Trigger policy deleted successfully"}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def delete_policy(_parent, _args, _resolution) do
    {:error, "Missing realm context"}
  end

  defp format_trigger(%Astarte.RealmManagement.Triggers.Trigger{} = trigger) do
    trigger
    |> struct_to_map()
    |> Map.drop([:__meta__, :trigger_uuid, :simple_triggers_uuids])
  end

  defp format_policy(%Astarte.Core.Triggers.Policy{} = policy) do
    policy
    |> struct_to_map()
    |> Map.drop([:__meta__])
  end

  defp struct_to_map(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> struct_to_map()
  end

  defp struct_to_map(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {k, struct_to_map(v)} end)
  end

  defp struct_to_map(list) when is_list(list) do
    Enum.map(list, &struct_to_map/1)
  end

  defp struct_to_map(other), do: other

  defp format_error(:already_installed_trigger), do: "Trigger already installed"
  defp format_error(:invalid_datastream_trigger), do: "Invalid datastream trigger"
  defp format_error(:unsupported_trigger_type), do: "Unsupported trigger type"
  defp format_error(:invalid_object_aggregation_trigger), do: "Invalid object aggregation trigger"
  defp format_error(:trigger_not_found), do: "Trigger not found"
  defp format_error(:trigger_policy_not_found), do: "Trigger policy not found"
  defp format_error(:already_installed_trigger_policy), do: "Trigger policy already installed"

  defp format_error(:cannot_delete_currently_used_trigger_policy),
    do: "Trigger policy currently used"

  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> inspect()
  end

  defp format_error(reason), do: inspect(reason)
end
