#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.Triggers do
  @moduledoc """
  The Triggers context.
  """

  import Ecto.Query, warn: false

  alias Astarte.RealmManagement.API.RPC.RealmManagement
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.RealmManagement.API.Triggers.Action
  alias Astarte.RealmManagement.API.Triggers.Trigger
  alias Ecto.Changeset

  require Logger

  @doc """
  Returns the list of triggers.
  """
  def list_triggers(realm_name) do
    with {:ok, triggers_list} <- RealmManagement.get_triggers_list(realm_name) do
      triggers_list
    end
  end

  @doc """
  Gets a single trigger.

  Returns {:ok, %Trigger{}} or {:error, reason} if there's an error.

  ## Examples

      iex> get_trigger(123)
      {:ok, %Trigger{}}

      iex> get_trigger(45)
      {:error, :not_found}

  """
  def get_trigger(realm_name, trigger_name) do
    with {:ok,
          %{
            trigger_name: name,
            trigger_action: action,
            tagged_simple_triggers: tagged_simple_triggers,
            policy: policy
          }} <- RealmManagement.get_trigger(realm_name, trigger_name),
         {:ok, action_map} <- Jason.decode(action) do
      simple_triggers_configs =
        Enum.map(tagged_simple_triggers, &SimpleTriggerConfig.from_tagged_simple_trigger/1)

      action_struct =
        %Action{}
        |> Changeset.cast(action_map, [
          :http_url,
          :http_method,
          :http_static_headers,
          :template,
          :template_type,
          :http_post_url,
          :ignore_ssl_errors,
          :amqp_exchange,
          :amqp_routing_key,
          :amqp_static_headers,
          :amqp_message_expiration_ms,
          :amqp_message_priority,
          :amqp_message_persistent
        ])
        |> Changeset.apply_changes()

      {:ok,
       %Trigger{
         name: name,
         action: action_struct,
         simple_triggers: simple_triggers_configs,
         policy: policy
       }}
    end
  end

  @doc """
  Creates a trigger.

  ## Examples

      iex> create_trigger(%{field: value})
      {:ok, %Trigger{}}

      iex> create_trigger(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_trigger(realm_name, attrs \\ %{}) do
    changeset =
      %Trigger{}
      |> Trigger.changeset(attrs, realm_name: realm_name)

    with {:ok, trigger_params} <- Changeset.apply_action(changeset, :insert),
         {:ok, encoded_action} <- Jason.encode(trigger_params.action),
         tagged_simple_triggers <-
           Enum.map(
             trigger_params.simple_triggers,
             &SimpleTriggerConfig.to_tagged_simple_trigger/1
           ),
         :ok <-
           RealmManagement.install_trigger(
             realm_name,
             trigger_params.name,
             trigger_params.policy,
             encoded_action,
             tagged_simple_triggers
           ) do
      {:ok, trigger_params}
    end
  end

  @doc """
  Deletes a Trigger.

  ## Examples

      iex> delete_trigger(trigger)
      {:ok, %Trigger{}}

      iex> delete_trigger(trigger)
      {:error, %Ecto.Changeset{}}

  """
  def delete_trigger(realm_name, %Trigger{} = trigger) do
    with :ok <- RealmManagement.delete_trigger(realm_name, trigger.name) do
      {:ok, trigger}
    end
  end
end
