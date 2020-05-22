#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.RealmManagement.API.Triggers.Trigger do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.RealmManagement.API.Triggers.{AMQPAction, HttpAction, Trigger}

  @derive {Phoenix.Param, key: :name}
  @primary_key false
  embedded_schema do
    field :name, :string
    field :action, :any, virtual: true
    embeds_one :amqp_action, AMQPAction
    embeds_one :http_action, HttpAction
    embeds_many :simple_triggers, SimpleTriggerConfig
  end

  @doc false
  def changeset(%Trigger{} = trigger, attrs) do
    attrs =
      attrs
      |> propagate_realm()
      |> move_action()

    trigger
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_embed(:amqp_action, required: false)
    |> cast_embed(:http_action, required: false)
    |> cast_embed(:simple_triggers, required: true)
    |> normalize()
  end

  def propagate_realm(%{realm_name: realm_name, action: action} = attrs) do
    updated_action = Map.put(action, :realm_name, realm_name)
    Map.put(attrs, :action, updated_action)
  end

  def propagate_realm(%{"realm_name" => realm_name, "action" => action} = attrs) do
    updated_action = Map.put(action, "realm_name", realm_name)
    Map.put(attrs, "action", updated_action)
  end

  def propagate_realm(attrs) do
    attrs
  end

  def move_action(%{action: action} = attrs) do
    choose_action_type(attrs, action)
  end

  def move_action(%{"action" => action} = attrs) do
    choose_action_type(attrs, action)
  end

  def choose_action_type(map, action) do
    type =
      case action do
        %{"amqp_exchange" => _} -> "amqp_action"
        %{amqp_exchange: _} -> :amqp_action
        %{"http_url" => _} -> "http_action"
        %{http_url: _} -> :http_action
        %{"http_post_url" => _} -> "http_action"
        %{http_post_url: _} -> :http_action
        _ -> nil
      end

    map
    |> Map.delete(type)
    |> Map.put(type, action)
  end

  def normalize(changeset) do
    amqp_action = get_field(changeset, :amqp_action)
    http_action = get_field(changeset, :http_action)

    case {amqp_action, http_action} do
      {nil, nil} ->
        changeset

      {_, nil} ->
        changeset
        |> delete_change(:amqp_action)
        |> put_change(:action, amqp_action)

      {nil, _} ->
        changeset
        |> delete_change(:http_action)
        |> put_change(:action, http_action)
    end
  end
end
