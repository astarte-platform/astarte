#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Core.Generators.MQTTPayloadTest do
  @moduledoc """
  Tests for the MQTT Payload generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Mapping, as: MappingGenerator
  alias Astarte.Core.Generators.MQTTPayload, as: MQTTPayloadGenerator
  alias Astarte.Core.Mapping

  defp value_matches_mapping?(:double, value), do: is_float(value)
  defp value_matches_mapping?(:integer, value), do: is_integer(value)
  defp value_matches_mapping?(:longinteger, value), do: is_integer(value)
  defp value_matches_mapping?(:boolean, value), do: is_boolean(value)
  defp value_matches_mapping?(:string, value), do: String.valid?(value)
  defp value_matches_mapping?(:binaryblob, value), do: is_binary(value)
  defp value_matches_mapping?(:datetime, value), do: match?(%DateTime{}, value)

  defp value_matches_mapping?(type, value)
       when type in [
              :doublearray,
              :integerarray,
              :booleanarray,
              :longintegerarray,
              :stringarray,
              :binaryblobarray,
              :datetimearray
            ] do
    base_type =
      case type do
        :doublearray -> :double
        :integerarray -> :integer
        :booleanarray -> :boolean
        :longintegerarray -> :longinteger
        :stringarray -> :string
        :binaryblobarray -> :binaryblob
        :datetimearray -> :datetime
      end

    Enum.all?(value, &value_matches_mapping?(base_type, &1))
  end

  @moduletag :core
  @moduletag :mqtt
  @moduletag :payload

  property "generated payloads are valid BSONs with 'v' and 't' keys" do
    check all payload <- MQTTPayloadGenerator.payload(), max_runs: 100 do
      assert %{"v" => _value, "t" => %DateTime{}} = Cyanide.decode!(payload)
    end
  end

  property "generated payloads honor the mapping type" do
    check all %Mapping{type: type} = mapping <- MappingGenerator.mapping(),
              payload <- MQTTPayloadGenerator.payload(mapping: mapping),
              %{"v" => value} = Cyanide.decode!(payload) do
      assert value_matches_mapping?(type, value)
    end
  end
end
