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

defmodule Astarte.RealmManagementWeb.ApiSpec.Schemas.TriggerDeliveryPolicyConfig do
  @moduledoc false

  require OpenApiSpex

  alias Astarte.RealmManagementWeb.ApiSpec.Schemas.TriggerDeliveryPolicyErrorHandler
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      name: %Schema{
        type: :string,
        pattern: ~S|^(?!@).+$|,
        minLength: 1,
        maxLength: 128,
        description: "Name of the trigger delivery policy."
      },
      maximum_capacity: %Schema{
        type: :integer,
        description: "Maximum size of the event queue of the trigger delivery policy.",
        minimum: 1,
        maximum: 1_000_000
      },
      error_handlers: %Schema{
        type: :array,
        minItems: 1,
        maxItems: 200,
        description: "Handlers for HTTP errors. Specify what action to take upon errors.",
        items: TriggerDeliveryPolicyErrorHandler
      },
      event_ttl: %Schema{
        type: :integer,
        description:
          "The amount of time (in seconds) an event will be retained in the event queue.",
        minimum: 1,
        maximum: 86_400
      },
      retry_times: %Schema{
        type: :integer,
        description:
          "The amount of times an event will be requeued if delivery fails and the related handler has 'retry' strategy.",
        minimum: 1,
        maximum: 100
      },
      prefetch_count: %Schema{
        type: :integer,
        description: "The maximum number of unacknowledged event messages a consumer can hold.",
        minimum: 1,
        maximum: 300
      }
    },
    required: [:name, :maximum_capacity, :error_handlers],
    example: %{
      name: "my_policy",
      maximum_capacity: 100,
      error_handlers: [
        %{
          "on" => "any_error",
          strategy: "discard"
        }
      ]
    }
  })
end
