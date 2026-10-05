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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.DeviceDeletionFinishedEventTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Triggers.SimpleEvents.DeviceDeletionFinishedEvent

  alias Astarte.Core.Generators.Triggers.SimpleEvents.DeviceDeletionFinishedEvent,
    as: DeviceDeletionFinishedEventGenerator

  @moduletag :trigger
  @moduletag :simple_event
  @moduletag :device_deletion_finished_event

  @doc false
  describe "triggers device_deletion_finished_event generator" do
    @describetag :success
    @describetag :ut
    property "generates valid device_deletion_finished_event" do
      check all device_deletion_finished_event <-
                  DeviceDeletionFinishedEventGenerator.device_deletion_finished_event() do
        assert %DeviceDeletionFinishedEvent{} = device_deletion_finished_event
      end
    end
  end
end
