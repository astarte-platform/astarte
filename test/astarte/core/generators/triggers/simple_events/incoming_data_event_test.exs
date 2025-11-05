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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.IncomingDataEventTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping.BSONValue, as: BSONValueGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.IncomingDataEvent,
    as: IncomingDataEventGenerator

  @moduletag :trigger
  @moduletag :simple_event
  @moduletag :incoming_data_event

  @doc false
  describe "triggers incoming_data_event generator" do
    @describetag :success
    @describetag :ut
    property "generates valid incoming_data_event" do
      check all incoming_data_event <- IncomingDataEventGenerator.incoming_data_event() do
        assert %IncomingDataEvent{} = incoming_data_event
      end
    end

    property "generates valid incoming_data_event using interface" do
      check all interface <- InterfaceGenerator.interface(),
                incoming_data_event <-
                  IncomingDataEventGenerator.incoming_data_event(interface: interface) do
        assert %IncomingDataEvent{} = incoming_data_event
      end
    end

    property "generates valid incoming_data_event using name and bson_value" do
      check all %Interface{name: interface_name} = interface <- InterfaceGenerator.interface(),
                bson_value <- BSONValueGenerator.bson_value(interface: interface),
                incoming_data_event <-
                  IncomingDataEventGenerator.incoming_data_event(
                    interface_name: interface_name,
                    bson_value: bson_value
                  ) do
        assert %IncomingDataEvent{} = incoming_data_event
      end
    end
  end
end
