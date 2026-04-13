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

defmodule Astarte.AppEngine.APIWeb.ApiSpec.Schemas.DeviceStatus do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  @previous_interface_schema %Schema{
    type: :object,
    description:
      "An object representing an interface that was previously declared in the introspection by the device",
    properties: %{
      name: %Schema{type: :string, description: "The name of the interface"},
      major: %Schema{type: :integer, description: "The major version of the interface"},
      minor: %Schema{type: :integer, description: "The minor version of the interface"},
      exchanged_msgs: %Schema{
        type: :integer,
        description:
          "The number of exchanged messages of this interface. Note that exchanged messages are the same for all (interface, major) combinations, i.e. com.my.Interface v1.2 will have the same exchanged_msgs of com.my.Interface v1.x for every value of x"
      },
      exchanged_bytes: %Schema{
        type: :integer,
        description:
          "The number of exchanged bytes of this interface. Note that exchanged bytes are the same for all (interface, major) combinations, i.e. com.my.Interface v1.2 will have the same exchanged_bytes of com.my.Interface v1.x for every value of x"
      }
    }
  }

  OpenApiSpex.schema(%{
    title: "DeviceStatus",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "The device ID."},
      aliases: %Schema{
        type: :object,
        description:
          "A set of aliases and their tags. Each alias has an unique tag that identifies its purpose."
      },
      attributes: %Schema{
        type: :object,
        description: "A set of attributes with their values. Each attribute has a unique key."
      },
      introspection: %Schema{
        type: :object,
        description:
          "A dictionary of available (installed) interfaces on the device. For each interface version major and minor versions are provided. Interfaces that are listed here might not be available on the server (e.g. not installed)."
      },
      connected: %Schema{
        type: :boolean,
        description: "True if the device is connected to the broker."
      },
      last_connection: %Schema{
        type: :string,
        format: :"date-time",
        description: "Last connection to the broker timestamp."
      },
      last_disconnection: %Schema{
        type: :string,
        format: :"date-time",
        description: "Last device disconnection timestamp."
      },
      first_registration: %Schema{
        type: :string,
        format: :"date-time",
        description: "First registration attempt timestamp."
      },
      first_credentials_request: %Schema{
        type: :string,
        format: :"date-time",
        description: "First credentials request timestamp."
      },
      last_seen_ip: %Schema{
        type: :string,
        description: "Last known device IP address."
      },
      credentials_inhibited: %Schema{
        type: :boolean,
        description:
          "true if the device has been inhibited (i.e. it can't request new credentials)"
      },
      last_credentials_request_ip: %Schema{
        type: :string,
        description: "Last known device IP address used while obtaining credentials."
      },
      total_received_bytes: %Schema{
        type: :integer,
        description: "Total amount of received payload bytes."
      },
      total_received_msgs: %Schema{
        type: :integer,
        description: "Total amount of received messages."
      },
      groups: %Schema{
        type: :array,
        description: "The groups the device belongs to.",
        items: %Schema{type: :string}
      },
      previous_interfaces: %Schema{
        type: :array,
        description: "The list of previously supported interfaces",
        items: @previous_interface_schema
      },
      deletion_in_progress: %Schema{
        type: :boolean,
        description: "True if the device is currently being deleted, false otherwise."
      }
    },
    example: %{
      id: "hm8AjtbN5P2mxo_gfXSfvQ",
      aliases: %{
        serial_number: "1234567",
        display_name: "my_device_name"
      },
      attributes: %{
        attribute_key: "attribute_value"
      },
      introspection: %{
        "com.example.ExampleInterface" => %{
          major: 2,
          minor: 0,
          exchanged_msgs: 20,
          exchanged_bytes: 200
        },
        "com.example.HelloWorldInterface" => %{
          major: 1,
          minor: 1,
          exchanged_msgs: 3,
          exchanged_bytes: 42
        }
      },
      connected: false,
      last_connection: "2017-09-28T03:45:00.000Z",
      last_disconnection: "2017-09-29T18:25:00.000Z",
      first_registration: "2016-07-08T09:44:00.000Z",
      first_credentials_request: "2016-08-20T09:44:00.000Z",
      last_seen_ip: "198.51.100.81",
      credentials_inhibited: false,
      last_credentials_request_ip: "98.51.100.89",
      total_received_bytes: 10_240,
      total_received_msgs: 10,
      groups: ["test-devices", "first-floor"],
      previous_interfaces: [
        %{
          name: "com.example.ExampleInterface",
          major: 1,
          minor: 1,
          exchanged_msgs: 5,
          exchanged_bytes: 102
        }
      ],
      deletion_in_progress: false
    }
  })
end
