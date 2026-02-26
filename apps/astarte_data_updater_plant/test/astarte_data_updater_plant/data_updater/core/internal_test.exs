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
  use Astarte.Cases.DataUpdater
  use ExUnitProperties
  use Mimic

  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.DataUpdater.State

  import Astarte.InterfaceUpdateGenerators

  describe "handle_internal/4" do
    test "handles heartbeat messages", test_context do
      %{state: state, interfaces: interfaces} = test_context

      %{state: state, timestamp: timestamp} =
        gen_context(state, interfaces)
        |> Enum.at(0)

      expect(Core.HeartbeatHandler, :handle_heartbeat, fn ^state, ^timestamp ->
        Core.HeartbeatHandler.handle_heartbeat(state, timestamp)
      end)

      assert {:ack, :ok, _new_state} =
               Core.InternalHandler.handle_internal(
                 state,
                 "/heartbeat",
                 :dontcare,
                 timestamp
               )
    end

    test "acks device deletion with a message on `/f` path", test_context do
      %{state: state} = test_context
      %State{realm: realm, device_id: device_id} = state

      state = Map.put(state, :discard_messages, true)

      expect(Queries, :ack_end_device_deletion, fn ^realm, ^device_id -> :ok end)

      assert {:stop, :ack_end_device_deletion, :ack, ^state} =
               Core.InternalHandler.handle_internal(
                 state,
                 "/f",
                 :dontcare,
                 :dontcare
               )
    end

    test "errors in case of an unexpected internal message", test_context do
      %{state: state, interfaces: interfaces} = test_context

      %{state: state, path: path, payload: payload, timestamp: timestamp} =
        context =
        gen_context(state, interfaces)
        |> filter(fn context -> not (context.state.discard_messages and context.path == "/f") end)
        |> Enum.at(0)

      expect(Core.Error, :handle_error, fn error_context, _error ->
        assert error_context == %{context | interface: ""}
        {:discard, :reason, error_context.state, {:continue, :continue_arg}}
      end)

      assert {:discard, _reason, ^state, _continue_arg} =
               Core.InternalHandler.handle_internal(
                 state,
                 path,
                 payload,
                 timestamp
               )
    end
  end

  defp gen_context(state, interfaces) do
    gen all interface <- member_of(interfaces),
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
        path: update.path,
        timestamp: timestamp,
        payload: payload
      }
    end
  end
end
