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

defmodule Astarte.Core.Generators.MQTTTopic do
  @moduledoc """
  A Generator for a Astarte MQTT topics.
  """
  use Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Common.Generators.MQTT, as: MQTTGenerator
  alias Astarte.Core.Generators.Device, as: DeviceGenerarator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Realm, as: RealmGenerarator

  @doc """
  Generates an Astarte control topic, given an Astarte Realm and Astarte Device ID.
  The topic follows the guidelines outlined in
  https://docs.astarte-platform.org/astarte/latest/080-mqtt-v1-protocol.html#mqtt-topics-overview

  ## Examples

    iex> AstarteTopicGenerator.control_topic("test", "AUCPtpHLRcaArHhKHvRBHg") |> Enum.take(2)
    ["test/AUCPtpHLRcaArHhKHvRBHg/control/w", "test/AUCPtpHLRcaArHhKHvRBHg/control/F2/G"]
  """
  @spec control_topic(params :: keyword()) :: StreamData.t(MQTTGenerator.mqtt_topic())
  def control_topic(params \\ []) do
    params gen all realm_name <- RealmGenerarator.realm_name(),
                   device_id <- DeviceGenerarator.id(),
                   :_,
                   topic <-
                     MQTTGenerator.mqtt_topic(
                       chars: :alphanumeric,
                       pre: "#{realm_name}/#{device_id}/control/"
                     ),
                   params: params do
      topic
    end
  end

  @doc """
  Generates an Astarte data topic, given Astarte Realm, Astarte Device ID and Astarte Interface name.
  The topic follows the guidelines outlined in
  https://docs.astarte-platform.org/astarte/latest/080-mqtt-v1-protocol.html#mqtt-topics-overview

  ## Examples

    iex(50)> AstarteTopicGenerator.data_topic("test", "AUCPtpHLRcaArHhKHvRBHg", "com.my.Interface") |> Enum.take(2)
    ["test/AUCPtpHLRcaArHhKHvRBHg/com.my.Interface/L", "test/AUCPtpHLRcaArHhKHvRBHg/com.my.Interface/q1U/3Id"]
  """
  @spec data_topic(params :: keyword()) :: StreamData.t(MQTTGenerator.mqtt_topic())
  def data_topic(params \\ []) do
    params gen all realm_name <- RealmGenerarator.realm_name(),
                   device_id <- DeviceGenerarator.id(),
                   interface_name <- InterfaceGenerator.name(),
                   :_,
                   topic <-
                     MQTTGenerator.mqtt_topic(
                       chars: :alphanumeric,
                       pre: "#{realm_name}/#{device_id}/#{interface_name}/"
                     ),
                   params: params do
      topic
    end
  end
end
