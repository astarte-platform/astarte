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

  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Events.TriggersHandler.Core

  @typedoc "event type as defined in simple event (eg `:device_connected_event`)"
  @type event_type() :: atom()

  defdelegate register_target(realm_name, trigger_target), to: Core

  @spec dispatch_event(
          struct(),
          event_type(),
          AMQPTriggerTarget.t(),
          String.t(),
          Device.encoded_device_id(),
          integer(),
          String.t()
        ) :: :ok
  def dispatch_event(event, event_type, target, realm, hw_id, timestamp, policy_name) do
    %SimpleEvent{
      simple_trigger_id: target.simple_trigger_id,
      parent_trigger_id: target.parent_trigger_id,
      realm: realm,
      device_id: hw_id,
      timestamp: timestamp,
      event: {event_type, event}
    }
    |> Core.dispatch_event(target, policy_name)
  end
end
