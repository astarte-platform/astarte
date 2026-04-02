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

defmodule Astarte.RealmManagementWeb.ApiSpec.Schemas.TriggerDeliveryPolicyErrorHandler do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      on: %Schema{
        description: """
        The range of errors the handler refers to. Must be one of: 'any_error',
        'client_error', 'server_error' or a custom error range (e.g. '[418, 419, 420, 500]').
        """
      },
      strategy: %Schema{
        type: :string,
        enum: ["discard", "retry"],
        description:
          "What Astarte must do if an HTTP error occurs when delivering errors the handler refers to."
      }
    },
    required: [:on, :strategy],
    example: %{
      on: "any_error",
      strategy: "discard"
    }
  })
end
