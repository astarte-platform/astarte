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

defmodule Astarte.RealmManagementWeb.ApiSpec.Schemas.DeviceSimpleTrigger do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    description: "An object describing a simple trigger reacting to device state changes.",
    properties: %{
      on: %Schema{
        type: :string,
        enum: [
          "device_connected",
          "device_disconnected",
          "device_empty_cache_received",
          "device_error"
        ],
        description: "The type of device event the trigger will react to."
      },
      type: %Schema{
        type: :string,
        enum: ["device_trigger"],
        description: "The type of the simple trigger, must be device_trigger."
      },
      device_id: %Schema{
        type: :string,
        description: "The device id the trigger will be restricted to."
      },
      group_name: %Schema{
        type: :string,
        description: "The group name the trigger will be restricted to."
      }
    },
    required: [:type, :on]
  })
end
