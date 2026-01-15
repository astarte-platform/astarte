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

defmodule Astarte.Common.Generators.MQTTTest do
  @moduledoc """
  Tests for the MQTT generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Common.Generators.MQTT, as: MQTTGenerator

  @moduletag :common
  @moduletag :mqtt
  @moduletag :topic

  describe "generic mqtt topic generator" do
    @describetag :success
    @describetag :ut
    property "generate topics do not have empty tokens by default" do
      check all topic <- MQTTGenerator.mqtt_topic() do
        refute String.contains?(topic, "//")
      end
    end

    property "generate topics cannot be a null string by default" do
      check all topic <- MQTTGenerator.mqtt_topic() do
        refute String.equivalent?(topic, "")
      end
    end

    property "generate topics with prefix option honor it" do
      check all pre <- string(MQTTGenerator.valid_chars()),
                topic <- MQTTGenerator.mqtt_topic(pre: pre) do
        assert String.starts_with?(topic, pre)
      end
    end
  end
end
