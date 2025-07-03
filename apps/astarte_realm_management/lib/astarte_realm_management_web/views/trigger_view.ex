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

defmodule Astarte.RealmManagementWeb.TriggerView do
  use Astarte.RealmManagementWeb, :view
  alias Astarte.RealmManagementWeb.TriggerView

  def render("index.json", %{triggers: triggers}) do
    %{data: render_many(triggers, TriggerView, "trigger_name_only.json")}
  end

  def render("show.json", %{trigger: trigger}) do
    %{data: render_one(trigger, TriggerView, "trigger.json")}
  end

  def render("already_installed_trigger.json", _assigns) do
    %{errors: %{detail: "Trigger already exists"}}
  end

  def render("invalid_datastream_trigger.json", _assigns) do
    %{errors: %{detail: "Invalid datastream trigger"}}
  end

  def render("unsupported_trigger_type.json", _assigns) do
    %{errors: %{detail: "Unsupported trigger type"}}
  end

  def render("invalid_object_aggregation_trigger.json", _assigns) do
    %{errors: %{detail: "Invalid object aggregation trigger"}}
  end

  def render("cannot_retrieve_simple_trigger.json", _assigns) do
    %{errors: %{detail: "Could not get trigger"}}
  end

  def render("cannot_delete_simple_trigger.json", _assigns) do
    %{errors: %{detail: "Could not delete trigger"}}
  end

  def render("trigger.json", %{trigger: trigger}) do
    %{
      name: trigger.name,
      action: trigger.action,
      simple_triggers: trigger.simple_triggers
    }
    |> maybe_add_policy(trigger.policy)
  end

  def render("trigger_name_only.json", %{trigger: trigger}) do
    trigger
  end

  defp maybe_add_policy(trigger, nil), do: trigger
  defp maybe_add_policy(trigger, policy), do: Map.put(trigger, :policy, policy)
end
