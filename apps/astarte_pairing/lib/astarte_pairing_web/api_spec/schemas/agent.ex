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

defmodule Astarte.PairingWeb.ApiSpec.Schemas.Agent do
  @moduledoc false
  alias OpenApiSpex.Schema

  defmodule IntrospectionEntry do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "IntrospectionEntry",
      type: :object,
      properties: %{
        major: %Schema{
          type: :integer,
          minimum: 0,
          description: "The major version of the interface"
        },
        minor: %Schema{
          type: :integer,
          minimum: 0,
          description: "The minor version of the interface"
        }
      },
      required: [:major, :minor]
    })
  end

  defmodule DeviceRegistrationRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DeviceRegistrationRequest",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            hw_id: %Schema{
              type: :string
            },
            initial_introspection: %Schema{
              type: :object,
              description: """
              An optional object specifying the initial introspection for the device. The keys
              of the object are the interface names, while the values are objects with the "major"
              and "minor" properties, specifying the major and minor version of the interface
              that is going to be supported by the device.
              """,
              additionalProperties: IntrospectionEntry
            }
          },
          required: [:hw_id]
        }
      },
      example: %{
        data: %{
          hw_id: "YHjKs3SMTgqq09eD7fzm6w",
          initial_introspection: %{
            "org.astarte-platform.genericsensors.Values" => %{
              major: 1,
              minor: 0
            },
            "org.astarte-platform.genericsensors.AvailableSensors" => %{
              major: 0,
              minor: 1
            }
          }
        }
      },
      required: [:data]
    })
  end

  defmodule DeviceRegistrationResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DeviceRegistrationResponse",
      type: :object,
      properties: %{
        credentials_secret: %Schema{
          type: :string
        }
      },
      example: %{
        credentials_secret: "TTkd5OgB13X/3qU0LXU7OCxyTXz5QHM2NY1IgidtPOs="
      }
    })
  end
end
