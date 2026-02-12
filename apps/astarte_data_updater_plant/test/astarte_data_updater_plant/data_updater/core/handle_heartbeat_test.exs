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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.HandleHeartbeatTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties
  use Mimic

  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.TimeBasedActions

  import Astarte.Helpers.DataUpdater

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state}
  end

  describe "handle_heartbeat/5" do
    test "discards messages according to state", test_context do
      %{state: state} = test_context

      state = Map.put(state, :discard_messages, true)
      %State{message_tracker: message_tracker} = state
      message_id = gen_message_id()

      expect(MessageTracker, :discard, fn ^message_tracker, ^message_id -> :ok end)
      assert ^state = Core.HeartbeatHandler.handle_heartbeat(state, message_id, :dontcare)
    end

    test "answers with updated state", test_context do
      %{state: state} = test_context

      %State{message_tracker: message_tracker, realm: realm, device_id: device_id} = state
      message_id = gen_message_id()
      timestamp = DateTime.utc_now(:millisecond)

      expect(TimeBasedActions, :execute_time_based_actions, fn ^state, ^timestamp -> state end)
      expect(Queries, :maybe_refresh_device_connected!, fn ^realm, ^device_id -> :ok end)
      expect(MessageTracker, :ack_delivery, fn ^message_tracker, ^message_id -> :ok end)

      new_state = Core.HeartbeatHandler.handle_heartbeat(state, message_id, timestamp)

      assert new_state == %{state | connected: true, last_seen_message: timestamp}
    end
  end

  defp gen_message_id, do: :erlang.unique_integer([:monotonic]) |> Integer.to_string()
end
