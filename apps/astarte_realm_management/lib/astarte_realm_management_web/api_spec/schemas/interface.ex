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

defmodule Astarte.RealmManagementWeb.ApiSpec.Schemas.Interface do
  @moduledoc false

  require OpenApiSpex

  alias Astarte.RealmManagementWeb.ApiSpec.Schemas.Mapping
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      interface_name: %Schema{
        type: :string,
        pattern:
          "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$",
        minLength: 1,
        maxLength: 128,
        description: """
        The name of the interface. This has to be an unique, alphanumeric
        reverse internet domain name, shorther than 128 characters.
        """
      },
      version_major: %Schema{
        type: :integer,
        description: """
        A Major version qualifier for this interface. Interfaces with the
        same id and different version_major number are deemed incompatible.
        It is then acceptable to redefine any property of the interface when
        changing the major version number.
        """
      },
      version_minor: %Schema{
        type: :integer,
        description: """
        A Minor version qualifier for this interface. Interfaces with the
        same id and major version number and different version_minor number
        are deemed compatible between each other. When changing the minor
        number, it is then only possible to insert further mappings. Any
        other modification might lead to incompatibilities and undefined
        behavior.
        """
      },
      type: %Schema{
        type: :string,
        enum: ["datastream", "properties"],
        description: """
        Identifies the type of this Interface. Currently two types are
        supported: datastream and properties. datastream should be used when
        dealing with streams of non-persistent data, where a single path
        receives updates and there's no concept of state. properties,
        instead, are meant to be an actual state and as such they have only
        a change history, and are retained.
        """
      },
      ownership: %Schema{
        type: :string,
        enum: ["device", "server"],
        description: """
        Identifies the ownership of the interface. Interfaces are meant to
        be unidirectional, and this property defines who's sending or
        receiving data. device means the device/gateway is sending data to
        Astarte, server means the device/gateway is receiving data from
        Astarte. Bidirectional mode is not supported, you should instantiate
        another interface for that.
        """
      },
      aggregation: %Schema{
        type: :string,
        enum: ["individual", "object"],
        default: "individual",
        description: """
        Identifies the aggregation of the mappings of the interface.
        Individual means every mapping changes state or streams data
        independently, whereas an object aggregation treats the interface as
        an object, making all the mappings changes interdependent. Choosing
        the right aggregation might drastically improve performances.
        """
      },
      description: %Schema{
        type: :string,
        description: "An optional description of the interface."
      },
      doc: %Schema{
        type: :string,
        description:
          "A string containing documentation that will be injected in the generated client code."
      },
      mappings: %Schema{
        type: :array,
        description: """
        Mappings define the endpoint of the interface, where actual data is
        stored/streamed. They are defined as relative URLs (e.g. /my/path)
        and can be parametrized (e.g.: /%{myparam}/path). A valid interface
        must have no mappings clash, which means that every mapping must
        resolve to a unique path or collection of paths (including
        parametrization). Every mapping acquires type, quality and
        aggregation of the interface.
        """,
        items: Mapping,
        minItems: 1,
        maxItems: 1024,
        uniqueItems: true
      }
    },
    required: [:interface_name, :version_minor, :version_major, :type, :ownership, :mappings],
    example: %{
      interface_name: "org.astarteplatform.Values",
      version_major: 0,
      version_minor: 1,
      type: "datastream",
      ownership: "device",
      mappings: [
        %{
          endpoint: "/realValue",
          type: "double",
          explicit_timestamp: true
        }
      ]
    }
  })
end
