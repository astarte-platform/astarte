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

defmodule Astarte.Core.Generators.MQTTPayload do
  @moduledoc """
  A generator for Astarte data payloads.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Common.Generators.DateTime, as: DateTimeGenerator
  alias Astarte.Core.Generators.Mapping, as: MappingGenerator
  alias Astarte.Core.Mapping

  @type astarte_payload :: Cyanide.bson_type()

  @doc """
  Generates a random payload as described in
  https://docs.astarte-platform.org/astarte/latest/080-mqtt-v1-protocol.html#payload-format.
  The optional `mapping` parameter allows to specify a mapping according to which the
  payload is to be generated.

  ## Examples

    iex> MQTTPayloadGenerator.payload() |> Enum.take(1)
    [
      <<24, 0, 0, 0, 9, 116, 0, 59, 115, 119, 124, 150, 1, 0, 0, 2, 118, 0, 1, 0, 0,
        0, 0, 0>>
    ]


    iex> MQTTPayloadGenerator.payload(mapping: %Mapping{value_type: :double}) |> Enum.take(1)
    [
      <<27, 0, 0, 0, 9, 116, 0, 218, 95, 121, 124, 150, 1, 0, 0, 1, 118, 0, 0, 0, 0,
        0, 0, 0, 240, 191, 0>>
    ]
  """
  @spec payload() :: StreamData.t(astarte_payload())
  @spec payload(params :: keyword()) :: StreamData.t(astarte_payload())
  def payload(params \\ []) do
    params gen all mapping <- MappingGenerator.mapping(),
                   %Mapping{type: type} = mapping,
                   timestamp <- DateTimeGenerator.date_time(),
                   value <- value(type),
                   {:ok, bson} = Cyanide.encode(%{"v" => value, "t" => timestamp}),
                   params: params do
      bson
    end
  end

  defp value(:double), do: float()
  defp value(:integer), do: integer()
  defp value(:boolean), do: boolean()
  defp value(:longinteger), do: integer()
  defp value(:string), do: string(:utf8)
  defp value(:binaryblob), do: binary()

  defp value(:datetime), do: DateTimeGenerator.date_time()

  defp value(:doublearray), do: list_of(float())
  defp value(:integerarray), do: list_of(integer())
  defp value(:booleanarray), do: list_of(boolean())
  defp value(:longintegerarray), do: list_of(integer())
  defp value(:stringarray), do: list_of(string(:utf8))
  defp value(:binaryblobarray), do: list_of(binary())

  defp value(:datetimearray), do: DateTimeGenerator.date_time() |> list_of()
end
