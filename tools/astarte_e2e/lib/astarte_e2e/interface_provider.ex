#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E.InterfaceProvider do
  alias Astarte.Device.SimpleInterfaceProvider

  @property_string_interface %{
    interface_name: "org.astarte-platform.e2etest.SimpleProperties",
    version_major: 1,
    version_minor: 0,
    type: "properties",
    ownership: "device",
    description: """
    SimpleProperties allows to send custom strings. Each string is employed to assess the end to end functionality of Astarte.
    """,
    mappings: [
      %{
        endpoint: "/correlationId",
        type: "string"
      }
    ]
  }

  @datastream_string_interface %{
    interface_name: "org.astarte-platform.e2etest.SimpleDatastream",
    version_major: 1,
    version_minor: 0,
    type: "datastream",
    ownership: "device",
    description: """
    SimpleDatastream allows to stream custom strings. Each string is employed to assess the end to end functionality of Astarte.
    """,
    mappings: [
      %{
        endpoint: "/correlationId",
        type: "string",
        database_retention_ttl: 500,
        description: """
        Each correlationId persists into the database for a predefined amount of time as to avoid an unbounded collection of entries.
        """
      }
    ]
  }

  @user_interfaces [
    @property_string_interface,
    @datastream_string_interface
  ]

  def standard_interface_provider! do
    {SimpleInterfaceProvider, interfaces: @user_interfaces}
  end

  def standard_interface_provider do
    {:ok, {SimpleInterfaceProvider, interfaces: @user_interfaces}}
  end
end
