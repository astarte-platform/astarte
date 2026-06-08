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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.SimpleEventTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent

  alias Astarte.Core.Generators.Triggers.SimpleEvents.SimpleEvent, as: SimpleEventGenerator

  @moduletag :trigger
  @moduletag :simple_event

  describe "triggers simple_event generator" do
    @describetag :success
    @describetag :ut
    property "generates valid simple_event" do
      check all simple_event <- SimpleEventGenerator.simple_event() do
        assert %SimpleEvent{} = simple_event
      end
    end

    property "encode and decode must be the same struct" do
      check all check_simple_event <- SimpleEventGenerator.simple_event() do
        simple_event = check_simple_event |> SimpleEvent.encode() |> SimpleEvent.decode()
        assert check_simple_event == simple_event
      end
    end
  end
end
