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

defmodule Astarte.RealmManagementWeb.ApiSpec.Schemas.HTTPPostAction do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    description: """
    An object describing an HTTP post action that will be executed by the
    trigger
    """,
    properties: %{
      http_post_url: %Schema{type: :string, description: "The target URL for the POST"},
      ignore_ssl_errors: %Schema{
        type: :boolean,
        default: false,
        description: "If true, ignore SSL errors when performing the HTTP request."
      },
      template_type: %Schema{
        type: :string,
        enum: ["mustache"],
        description: """
        The type of template used for the POST request, if any. If not
        specified, the payload of the POST will be a JSON object
        representing the event.
        """
      },
      template: %Schema{
        type: :string,
        description:
          "If a template_type is specified, this should contain the template to be applied.",
        example: "Just received {{value}} from {{device_id}}"
      }
    },
    required: [:http_post_url]
  })
end
