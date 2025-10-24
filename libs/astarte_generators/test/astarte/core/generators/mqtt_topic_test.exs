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

defmodule Astarte.Core.Generators.MQTTTopicTest do
  @moduledoc """
  Tests for the Astarte topic generator
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.MQTTTopic, as: MQTTTopicGenerator
  alias Astarte.Core.Generators.Realm, as: RealmGenerator

  @moduletag :core
  @moduletag :mqtt
  @moduletag :topic

  describe "generate astarte topics" do
    @describetag :success
    @describetag :ut
    property "control_topic/2" do
      check all topic <- MQTTTopicGenerator.control_topic() do
        refute is_nil(topic)
      end
    end

    property "data_topic/2" do
      check all topic <- MQTTTopicGenerator.data_topic() do
        refute is_nil(topic)
      end
    end
  end

  describe "generate astarte topics with correct prefixes" do
    @describetag :success
    @describetag :ut
    property "control_topic/2" do
      check all realm_name <- RealmGenerator.realm_name(),
                device_id <- DeviceGenerator.id(),
                topic <-
                  MQTTTopicGenerator.control_topic(
                    realm_name: realm_name,
                    device_id: device_id
                  ) do
        assert String.starts_with?(topic, "#{realm_name}/#{device_id}/control/")
      end
    end

    property "data_topic/3" do
      check all realm_name <- RealmGenerator.realm_name(),
                device_id <- DeviceGenerator.id(),
                interface_name <- InterfaceGenerator.name(),
                topic <-
                  MQTTTopicGenerator.data_topic(
                    realm_name: realm_name,
                    device_id: device_id,
                    interface_name: interface_name
                  ) do
        assert String.starts_with?(topic, "#{realm_name}/#{device_id}/#{interface_name}/")
      end
    end
  end
end
