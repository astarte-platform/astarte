#
# This file is part of Astarte.
#
# Copyright 2018-2020 Ispirata Srl
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
  alias Ecto.Changeset
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.RealmManagement.API.Triggers.{Action, AMQPAction, HttpAction, Trigger}

  @derive {Phoenix.Param, key: :name}
  @primary_key false
  embedded_schema do
    field :name, :string
    embeds_one :action, Action
    field :policy, :string
    embeds_one :amqp_action, AMQPAction
    embeds_one :http_action, HttpAction
    embeds_many :simple_triggers, SimpleTriggerConfig
  end

  @doc false
  def changeset(%Trigger{} = trigger, attrs, opts) do
    attrs = move_action(attrs)

    trigger
    |> cast(attrs, [:name, :policy])
    |> validate_required([:name])
    |> validate_length(:policy, max: 128)
    |> validate_format(:policy, policy_name_regex())
    |> cast_embed(:amqp_action, required: false, with: {AMQPAction, :changeset, [opts]})
    |> cast_embed(:http_action, required: false)
    |> cast_embed(:simple_triggers, required: true)
    |> normalize()
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
    amqp_action = get_change(changeset, :amqp_action)
    http_action = get_change(changeset, :http_action)

    case {amqp_action, http_action} do
      {nil, nil} ->
        changeset

      {_, nil} ->
        normalize_action(changeset, amqp_action)

      {nil, _} ->
        normalize_action(changeset, http_action)
    end
  end

  defp normalize_action(parent_changeset, action_changeset) do
    %Changeset{changes: changes, errors: errors} = action_changeset

    parent_changeset
    |> delete_change(:amqp_action)
    |> delete_change(:http_action)
    |> put_change(:action, changes)
    |> put_errors(:action, errors)
  end

  defp put_errors(changeset, field, errors) do
    Enum.reduce(errors, changeset, fn {subfield, {message, keys}}, acc ->
      Changeset.update_change(acc, field, fn sub_changeset ->
        Changeset.add_error(sub_changeset, subfield, message, keys)
      end)
    end)
  end

  def policy_name_regex do
    ~r/^(?!@).+$/
  end
end
