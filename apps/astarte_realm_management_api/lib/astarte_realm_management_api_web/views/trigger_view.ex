#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.APIWeb.TriggerView do
  use Astarte.RealmManagement.APIWeb, :view
  alias Astarte.RealmManagement.APIWeb.TriggerView
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer

  use Astarte.Core.Triggers.SimpleTriggersProtobuf

  def render("index.json", %{triggers: triggers}) do
    %{data: render_many(triggers, TriggerView, "trigger_name_only.json")}
  end

  def render("show.json", %{trigger: trigger}) do
    %{data: render_one(trigger, TriggerView, "trigger.json")}
  end

  def render("trigger.json", %{trigger: trigger}) do
    %{
      id: trigger.name,
      action: trigger.action,
      simple_triggers: transform_simple_triggers(trigger.simple_triggers)
    }
  end

  def render("trigger_name_only.json", %{trigger: trigger}) do
    trigger
  end

  def transform_simple_triggers(nil) do
    nil
  end

  def transform_simple_triggers(simple_triggers) do
    for item <- simple_triggers do
      %{
        object_id: object_id,
        object_type: object_type,
        simple_trigger: %SimpleTriggerContainer{simple_trigger: {:data_trigger, simple_trigger}}
      } = item

      %{
        object_id: to_string(:uuid.uuid_to_string(object_id)),
        object_type: object_type,
        simple_trigger: simple_trigger
      }
    end
  end

  defimpl Poison.Encoder, for: DataTrigger do
    def encode(data_trigger, options) do
      %{v: known_value} = Bson.decode(data_trigger.known_value)

      %{
        "type" => "DataTrigger",
        "on" => data_trigger.data_trigger_type,
        "interface_id" => to_string(:uuid.uuid_to_string(data_trigger.interface_id)),
        "known_value" => known_value,
        "match_path" => data_trigger.match_path,
        "value_match_operator" => data_trigger.value_match_operator
      }
      |> Poison.Encoder.Map.encode(options)
    end
  end

end
