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

defmodule Astarte.RealmManagementWeb.ApiSpec.Schemas.DataSimpleTrigger do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    description: "An object describing a simple trigger reacting to published data.",
    properties: %{
      on: %Schema{
        type: :string,
        enum: [
          "incoming_data",
          "value_change",
          "value_change_applied",
          "path_created",
          "path_removed",
          "value_stored"
        ],
        description: "The type of data event the trigger will react to"
      },
      type: %Schema{
        type: :string,
        enum: ["data_trigger"],
        description: "The type of the simple trigger, must be data_trigger."
      },
      device_id: %Schema{
        type: :string,
        description: "The device id the trigger will be restricted to."
      },
      group_name: %Schema{
        type: :string,
        description: "The group name the trigger will be restricted to."
      },
      interface_name: %Schema{
        type: :string,
        description: "The name of the target interface or * to match all interfaces."
      },
      interface_major: %Schema{
        type: :integer,
        description: """
        The major version of the target interface. Ignored if interface_name
        is *.
        """
      },
      match_path: %Schema{
        type: :string,
        description: """
        The target endpoint path for the trigger or /* to match all the
        endpoints of the target interface.
        """
      },
      known_value: %Schema{
        description: """
        Used with value_match_operator to determine whether to activate the
        trigger or not. The known value is used in the right hand side of
        the comparison, e.g. if known_value is 0.6 and value_match_operator
        is >, the trigger will be activated only if the published value is >
        0.6. The type of this value must be the same of the published value.
        Ignored if value_match_operator is *.
        """
      },
      value_match_operator: %Schema{
        type: :string,
        enum: ["*", "==", "!=", ">", ">=", "<", "<=", "contains", "not_contains"],
        description: """
        A comparison operator used with known_value or * to match
        everything. See also known_value.
        """
      }
    },
    required: [:type, :interface_name, :match_path, :on, :value_match_operator]
  })
end
