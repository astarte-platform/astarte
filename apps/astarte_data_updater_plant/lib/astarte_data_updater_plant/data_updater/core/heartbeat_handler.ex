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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.HeartbeatHandler do
  @moduledoc """
  Heartbeat messages handler.
  """
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.TimeBasedActions
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater.State

  require Logger

  def handle_heartbeat(%State{discard_messages: true} = state, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  # TODO make this private when all heartbeats will be moved to internal
  def handle_heartbeat(state, message_id, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    Queries.maybe_refresh_device_connected!(new_state.realm, new_state.device_id)

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device heartbeat.", tag: "device_heartbeat")

    %{new_state | connected: true, last_seen_message: timestamp}
  end
end
