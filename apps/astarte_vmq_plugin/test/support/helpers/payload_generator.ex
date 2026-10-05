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

defmodule Astarte.VMQ.Plugin.Test.Helpers.PayloadGenerator do
  @moduledoc "StreamData generators for Astarte BSON payloads."
  use ExUnitProperties

  alias Astarte.Common.Generators.Timestamp
  alias Astarte.Core.Mapping

  @doc """
  Generates a valid Astarte data payload as described in
  https://docs.astarte-platform.org/astarte/latest/080-mqtt-v1-protocol.html#payload-format
  The optional `mapping` parameter allows to generate
  valid payloads for a given mapping.
  """
  def payload(opts \\ []) do
    mapping = Keyword.get(opts, :mapping)

    if mapping != nil do
      payload_for(mapping)
    else
      generic_payload()
    end
  end

  defp payload_for(%Mapping{} = mapping) do
    generator = generator_for_value_type(mapping.value_type)

    gen all(
          value <- generator,
          timestamp <- Timestamp.timestamp()
        ) do
      {:ok, bson} = Cyanide.encode(%{"v" => value, "t" => timestamp})
      bson
    end
  end

  defp generator_for_value_type(:double), do: float()
  defp generator_for_value_type(:integer), do: integer()
  defp generator_for_value_type(:boolean), do: boolean()
  defp generator_for_value_type(:longinteger), do: integer()
  defp generator_for_value_type(:string), do: string(:utf8)
  defp generator_for_value_type(:binaryblob), do: binary()
  defp generator_for_value_type(:datetime), do: Timestamp.timestamp()
  defp generator_for_value_type(:doublearray), do: list_of(float())
  defp generator_for_value_type(:integerarray), do: list_of(integer())
  defp generator_for_value_type(:booleanarray), do: list_of(boolean())
  defp generator_for_value_type(:longintegerarray), do: list_of(integer())
  defp generator_for_value_type(:stringarray), do: list_of(string(:utf8))
  defp generator_for_value_type(:binaryblobarray), do: list_of(binary())
  defp generator_for_value_type(:datetimearray), do: list_of(Timestamp.timestamp())

  defp generic_payload do
    gen all(
          value <-
            one_of([
              integer(),
              float(),
              binary(),
              string(:utf8),
              boolean(),
              Timestamp.timestamp(),
              list_of(integer()),
              list_of(float()),
              list_of(binary()),
              list_of(string(:utf8)),
              list_of(boolean()),
              list_of(Timestamp.timestamp())
            ]),
          timestamp <- Timestamp.timestamp()
        ) do
      {:ok, bson} = Cyanide.encode(%{"v" => value, "t" => timestamp})
      bson
    end
  end
end
