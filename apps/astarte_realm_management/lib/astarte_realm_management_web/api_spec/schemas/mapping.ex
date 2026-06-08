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

defmodule Astarte.RealmManagementWeb.ApiSpec.Schemas.Mapping do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    description: """
    Identifies a mapping for an interface. A mapping must consist at least
    of an endpoint and a type.
    """,
    properties: %{
      endpoint: %Schema{
        type: :string,
        pattern: "^(/(%{([a-zA-Z][a-zA-Z0-9]*)}|[a-zA-Z][a-zA-Z0-9]*)){1,64}$",
        minLength: 2,
        maxLength: 256,
        description: """
        The template of the path. This is a UNIX-like path (e.g. /my/path)
        and can be parametrized. Parameters are in the %{name} form, and can
        be used to create interfaces which represent dictionaries of
        mappings. When the interface aggregation is object, an object is
        composed by all the mappings for one specific parameter combination.
        /timestamp is a reserved path for timestamps, so every mapping on a
        datastream must not have any endpoint that ends with /timestamp.
        """
      },
      type: %Schema{
        type: :string,
        enum: [
          "double",
          "integer",
          "boolean",
          "longinteger",
          "string",
          "binaryblob",
          "datetime",
          "doublearray",
          "integerarray",
          "booleanarray",
          "longintegerarray",
          "stringarray",
          "binaryblobarray",
          "datetimearray"
        ],
        description: "Defines the type of the mapping."
      },
      reliability: %Schema{
        type: :string,
        enum: ["unreliable", "guaranteed", "unique"],
        default: "unreliable",
        description: """
        Useful only with datastream. Defines whether the sent data should be
        considered delivered when the transport successfully sends the data
        (unreliable), when we know that the data has been received at least
        once (guaranteed) or when we know that the data has been received
        exactly once (unique). unreliable by default. When using reliable
        data, consider you might incur in additional resource usage on both
        the transport and the device's end.
        """
      },
      retention: %Schema{
        type: :string,
        enum: ["discard", "volatile", "stored"],
        default: "discard",
        description: """
        Useful only with datastream. Defines whether the sent data should be
        discarded if the transport is temporarily uncapable of delivering it
        (discard) or should be kept in a cache in memory (volatile) or on
        disk (stored), and guaranteed to be delivered in the timeframe
        defined by the expiry. discard by default.
        """
      },
      expiry: %Schema{
        type: :integer,
        default: 0,
        description: """
        Useful when retention is stored. Defines after how many seconds a
        specific data entry should be kept before giving up and erasing it
        from the persistent cache. A value <= 0 means the persistent cache
        never expires, and is the default.
        """
      },
      allow_unset: %Schema{
        type: :boolean,
        default: false,
        description: """
        Used only with properties. Used with producers, it generates a
        method to unset the property. Used with consumers, it generates code
        to call an unset method when an empty payload is received.
        """
      },
      explicit_timestamp: %Schema{
        type: :boolean,
        default: false,
        description: """
        Allow to set a custom timestamp, otherwise a timestamp is added when
        the message is received. If true explicit timestamp will also be
        used for sorting. This feature is only supported on datastreams.
        """
      },
      description: %Schema{type: :string, description: "An optional description of the mapping."},
      doc: %Schema{
        type: :string,
        description:
          "A string containing documentation that will be injected in the generated client code."
      }
    },
    required: [:endpoint, :type]
  })
end
