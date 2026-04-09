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

defmodule Astarte.RealmManagementWeb.ApiSpec.Schemas.TriggerConfig do
  @moduledoc false

  require OpenApiSpex

  alias Astarte.RealmManagementWeb.ApiSpec.Schemas.{
    DataSimpleTrigger,
    DeviceSimpleTrigger,
    HTTPPostAction
  }

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      name: %Schema{type: :string, description: "Name of the trigger"},
      action: %Schema{oneOf: [HTTPPostAction]},
      simple_triggers: %Schema{
        type: :array,
        minItems: 1,
        maxItems: 1,
        description: """
        Simple triggers that will trigger the action. For now only a single
        simple trigger is supported.
        """,
        items: %Schema{oneOf: [DataSimpleTrigger, DeviceSimpleTrigger]}
      }
    },
    required: [:name, :action, :simple_triggers],
    example: %{
      name: "value_above_threshold_alarm",
      action: %{http_post_url: "http://example.com/my_post_url"},
      simple_triggers: [
        %{
          "on" => "incoming_data",
          type: "data_trigger",
          interface_name: "org.astarteplatform.Values",
          interface_major: 0,
          match_path: "/realValue",
          value_match_operator: ">",
          known_value: 0.6
        }
      ]
    }
  })
end
