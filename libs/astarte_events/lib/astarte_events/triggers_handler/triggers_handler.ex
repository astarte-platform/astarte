#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Events.TriggersHandler do
  @moduledoc """
  This module handles the triggers by generating the events requested
  by the Trigger targets
  """

  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Events.TriggersHandler.Core

  defdelegate register_target(realm_name, trigger_target), to: Core

  def dispatch_event(event, event_type, target, realm, device_id, timestamp, policy) do
    %SimpleEvent{
      simple_trigger_id: target.simple_trigger_id,
      parent_trigger_id: target.parent_trigger_id,
      realm: realm,
      device_id: device_id,
      timestamp: timestamp,
      event: {event_type, event}
    }
    |> Core.dispatch_event(target, policy)
  end
end
