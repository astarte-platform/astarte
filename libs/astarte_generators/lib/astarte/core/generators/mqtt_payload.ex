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

  alias Astarte.Core.Generators.Mapping.Payload, as: PayloadGenerator

  @type astarte_payload :: Cyanide.bson_type()

  @doc """
  Generates a random payload as described in
  https://docs.astarte-platform.org/astarte/latest/080-mqtt-v1-protocol.html#payload-format.

  ## Examples

    iex> MQTTPayloadGenerator.payload() |> Enum.take(1)
    [
      <<24, 0, 0, 0, 9, 116, 0, 59, 115, 119, 124, 150, 1, 0, 0, 2, 118, 0, 1, 0, 0,
        0, 0, 0>>
    ]


    iex> MQTTPayloadGenerator.payload(type: :double, m: %{meta: "data"}) |> Enum.take(1)
    [
      <<27, 0, 0, 0, 9, 116, 0, 218, 95, 121, 124, 150, 1, 0, 0, 1, 118, 0, 0, 0, 0,
        0, 0, 0, 240, 191, 0>>
    ]
  """
  @spec payload() :: StreamData.t(astarte_payload())
  @spec payload(params :: keyword()) :: StreamData.t(astarte_payload())
  def payload(params \\ []),
    do:
      PayloadGenerator.payload(params)
      |> map(fn payload ->
        {:ok, bson} = Cyanide.encode(payload)
        bson
      end)
end
