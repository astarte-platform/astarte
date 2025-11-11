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

defmodule Astarte.Common.Generators.MQTT do
  @moduledoc """
  A Generator for a standard MQTT stuff.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Generators.Utilities

  @type mqtt_topic() :: String.t()

  @utf8_except_slash_and_null [0x0001..0x002E, 0x0030..0xD7FF, 0xE000..0x10FFFF]

  @doc """
  Valid characters used by mqtt topics
  """
  @spec valid_chars() :: [Range.t(), ...]
  def valid_chars, do: @utf8_except_slash_and_null

  @doc """
  Generates a MQTT topic.
  The topic does not contain wildcards and follows the guidelines outlined
  in https://www.hivemq.com/blog/mqtt-essentials-part-5-mqtt-topics-best-practices/.
  The topic has at most 10 tokens and each one is at most 20 characters long.

  ## Examples

    iex> TopicGenerator.mqtt_topic(chars: :alphanumeric) |> Enum.take(4)
    ["n", "7/8X", "A/5TF", "6Nn/YISU/p"]

    iex> TopicGenerator.mqtt_topic(allow_empty: true) |> Enum.take(4)
    ["", "", "5OZ", ""]

    iex> TopicGenerator.mqtt_topic(chars: :alphanumeric, pre: "ratamahatta") |> Enum.take(4)
    ["ratamahattav", "ratamahattaOD", "ratamahattay49", "ratamahattayQ/vb5"]
  """
  @spec mqtt_topic() :: StreamData.t(mqtt_topic())
  @spec mqtt_topic(params :: keyword()) :: StreamData.t(mqtt_topic())
  def mqtt_topic(params \\ []) do
    params gen all chars <- constant(valid_chars()),
                   allow_empty <- constant(false),
                   pre <- constant(""),
                   topic <-
                     string(chars, min_length: 1, max_length: 20)
                     |> list_of(min_length: allow_empty_to_length(allow_empty), max_length: 10)
                     |> map(&Enum.join(&1, "/"))
                     |> Utilities.print(pre: pre),
                   params: params,
                   exclude: [:topic] do
      topic
    end
  end

  defp allow_empty_to_length(allow_empty) do
    if allow_empty, do: 0, else: 1
  end
end
