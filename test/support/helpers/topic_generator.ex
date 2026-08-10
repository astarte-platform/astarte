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

defmodule Astarte.VMQ.Plugin.Test.Helpers.TopicGenerator do
  @moduledoc "StreamData generators for valid MQTT topics."
  use ExUnitProperties

  @doc """
  Generates a MQTT topic.
  The topic does not contain wildcards and follows the guidelines outlined
  in https://www.hivemq.com/blog/mqtt-essentials-part-5-mqtt-topics-best-practices/
  """
  def mqtt_topic(opts \\ []) do
    allow_empty? = Keyword.get(opts, :allow_empty, false)
    min_length = if allow_empty?, do: 0, else: 1
    prefix = Keyword.get(opts, :prefix, "")

    # source for these numbers: it came to me once in a dream
    string(:alphanumeric, min_length: 1, max_length: 20)
    |> list_of(min_length: min_length, max_length: 10)
    |> map(&Enum.join(&1, "/"))
    |> map(&(prefix <> &1))
  end

  def control_topic(realm, device_id) do
    mqtt_topic(prefix: "#{realm}/#{device_id}/control/")
  end

  def data_topic(realm, device_id, interface) do
    mqtt_topic(prefix: "#{realm}/#{device_id}/#{interface}/")
  end
end
