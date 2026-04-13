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

defmodule Astarte.AppEngine.APIWeb.ApiSpec.Schemas.DeviceStatusByGroup do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "IndexGroupDevices",
    type: :object,
    properties: %{
      data: %Schema{
        type: :array,
        items: %Schema{type: :string},
        example: ["v8UxxIT9RkyPjIJZt6-Rrw", "fhd0WHcgSjWeVqPGKZv_KA"]
      }
    }
  })
end
