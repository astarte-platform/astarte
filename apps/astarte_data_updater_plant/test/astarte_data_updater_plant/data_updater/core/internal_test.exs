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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.InternalTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties
  use Mimic

  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  import Astarte.Helpers.DataUpdater
  import Astarte.InterfaceUpdateGenerators

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state}
  end

  describe "handle_internal/5" do
    test "handles heartbeat messages", test_context do
      %{state: state, interfaces: interfaces} = test_context

      %{state: state, message_id: message_id, timestamp: timestamp} =
        gen_context(state, interfaces)
        |> Enum.at(0)

      expect(Core.HeartbeatHandler, :handle_heartbeat, fn ^state, ^message_id, ^timestamp ->
        state
      end)

      assert {:continue, ^state} =
               Core.InternalHandler.handle_internal(
                 state,
                 "/heartbeat",
                 :dontcare,
                 message_id,
                 timestamp
               )
    end

    test "acks device deletion with a message on `/f` path", test_context do
      %{state: state, interfaces: interfaces} = test_context
      %State{realm: realm, device_id: device_id, message_tracker: message_tracker} = state
      %{message_id: message_id} = gen_context(state, interfaces) |> Enum.at(0)

      state = Map.put(state, :discard_messages, true)

      expect(Queries, :ack_end_device_deletion, fn ^realm, ^device_id -> :ok end)
      expect(MessageTracker, :ack_delivery, fn ^message_tracker, ^message_id -> :ok end)

      assert {:stop, ^state} =
               Core.InternalHandler.handle_internal(
                 state,
                 "/f",
                 :dontcare,
                 message_id,
                 :dontcare
               )
    end

    test "errors in case of an unexpected internal message", test_context do
      %{state: state, interfaces: interfaces} = test_context

      %{state: state, path: path, payload: payload, message_id: message_id, timestamp: timestamp} =
        context =
        gen_context(state, interfaces)
        |> filter(fn context -> not (context.state.discard_messages and context.path == "/f") end)
        |> Enum.at(0)

      expect(Core.Error, :handle_error, fn error_context, _error ->
        assert error_context == %{context | interface: ""}
        error_context.state
      end)

      assert {:continue, ^state} =
               Core.InternalHandler.handle_internal(
                 state,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end
  end

  defp gen_context(state, interfaces) do
    gen all interface <- member_of(interfaces),
            message_id <- repeatedly(&gen_message_id/0),
            update <- valid_mapping_update_for(interface),
            timestamp <- repeatedly(fn -> DateTime.utc_now(:millisecond) end) do
      payload =
        %{
          "v" => update.value,
          "t" => timestamp
        }
        |> Cyanide.encode!()

      %{
        state: state,
        interface: interface.name,
        message_id: message_id,
        path: update.path,
        timestamp: timestamp,
        payload: payload
      }
    end
  end

  defp gen_message_id, do: :erlang.unique_integer([:monotonic]) |> Integer.to_string()
end
