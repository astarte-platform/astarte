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
  StreamData helpers that emit valid Astarte MQTT topics for both control and data
  paths, honouring the MQTT topic layout described in the public protocol
  documentation.
  """
  use Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface

  alias Astarte.Common.Generators.MQTT, as: MQTTGenerator
  alias Astarte.Core.Generators.Device, as: DeviceGenerarator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Realm, as: RealmGenerarator

  @doc """
  Generates an Astarte control topic.
  The topic follows the guidelines outlined in
  https://docs.astarte-platform.org/astarte/latest/080-mqtt-v1-protocol.html#mqtt-topics-overview

  ## Examples

    iex> AstarteTopicGenerator.control_topic() |> Enum.take(1)
    ["a/GERcokEGASFg/control/w"]

    iex> AstarteTopicGenerator.control_topic(realm_name: "test", device_id: "AUCPtpHLRcaArHhKHvRBHg") |> Enum.take(2)
    ["test/AUCPtpHLRcaArHhKHvRBHg/control/w", "test/AUCPtpHLRcaArHhKHvRBHg/control/F2/G"]
  """
  @spec control_topic(params :: keyword()) :: StreamData.t(MQTTGenerator.mqtt_topic())
  def control_topic(params \\ []) do
    params gen all realm_name <- RealmGenerarator.realm_name(),
                   device <- DeviceGenerarator.device(),
                   %{id: device_id} = device,
                   device_id <- constant(device_id),
                   topic <-
                     MQTTGenerator.mqtt_topic(
                       chars: :alphanumeric,
                       pre: "#{realm_name}/#{device_id}/control/"
                     ),
                   params: params,
                   exclude: [:topic] do
      topic
    end
  end

  @doc """
  Generates an Astarte data topic, given a realm, a device id and an interface name.
  The topic follows the guidelines outlined in
  https://docs.astarte-platform.org/astarte/latest/080-mqtt-v1-protocol.html#mqtt-topics-overview

  ## Examples

    iex(50)> AstarteTopicGenerator.data_topic(realm_name: "test", device: DeviceGenerator.device()) |> Enum.take(2)
    ["test/AUCPtpHLRcaArHhKHvRBHg/com.my.Interface1/L", "test/AUCPtpHLRcaArHhKHvRBHg/com.my.Interface2/q1U/3Id"]
  """
  @spec data_topic(params :: keyword()) :: StreamData.t(MQTTGenerator.mqtt_topic())
  def data_topic(params \\ []) do
    params gen all realm_name <- RealmGenerarator.realm_name(),
                   interfaces <-
                     InterfaceGenerator.interface()
                     |> list_of(min_length: 1, max_length: 10),
                   device <- DeviceGenerarator.device(interfaces: interfaces),
                   %{id: device_id} = device,
                   device_id <- constant(device_id),
                   interface <- member_of(interfaces),
                   %Interface{name: interface_name} = interface,
                   interface_name <- constant(interface_name),
                   topic <-
                     MQTTGenerator.mqtt_topic(
                       chars: :alphanumeric,
                       pre: "#{realm_name}/#{device_id}/#{interface_name}/"
                     ),
                   params: params,
                   exclude: [:topic] do
      topic
    end
  end
end
