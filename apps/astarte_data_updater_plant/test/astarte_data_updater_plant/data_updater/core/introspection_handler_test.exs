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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.IntrospectionHandlerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Mimic
  use ExUnitProperties

  import StreamData
  import Astarte.Helpers.DataUpdater

  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.IntrospectionHandler
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.MessageTracker

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state, message_tracker: state.message_tracker}
  end

  setup do
    message_id = System.unique_integer()
    timestamp = System.system_time(:second)
    payload = System.unique_integer() |> to_string()

    %{
      message_id: message_id,
      payload: payload,
      timestamp: timestamp
    }
  end

  describe "handle_introspection tests" do
    test "discards messages if discard_messages is enabled", context do
      %{
        state: state,
        message_id: message_id,
        message_tracker: message_tracker
      } = context

      state = %{state | discard_messages: true}

      expect(MessageTracker, :discard, fn ^message_tracker, ^message_id -> :ok end)

      new_state = IntrospectionHandler.handle_introspection(state, "", message_id, 0)

      assert new_state == state
    end

    test "processes valid introspection", context do
      %{
        state: state,
        message_id: message_id,
        timestamp: timestamp,
        payload: payload
      } = context

      decoded_introspection = [%{interface: "com.test.testInterface", major: 1, minor: 0}]
      new_state = Map.put(state, :introspection, %{"com.test.testInterface" => 1})

      expect(PayloadsDecoder, :parse_introspection, fn ^payload ->
        {:ok, decoded_introspection}
      end)

      expect(Core.Device, :process_introspection, fn ^state,
                                                     ^decoded_introspection,
                                                     ^payload,
                                                     ^message_id,
                                                     ^timestamp ->
        new_state
      end)

      assert IntrospectionHandler.handle_introspection(state, payload, message_id, timestamp) ==
               new_state
    end

    test "returns error on invalid introspection", context do
      %{
        state: state,
        message_id: message_id,
        timestamp: timestamp,
        message_tracker: message_tracker
      } = context

      payload = "invalid_payload"
      new_state = state

      expect(PayloadsDecoder, :parse_introspection, fn ^payload ->
        {:error, :invalid_introspection}
      end)

      expect(Core.Device, :ask_clean_session, fn ^state, ^timestamp ->
        {:ok, new_state}
      end)

      expect(MessageTracker, :discard, fn ^message_tracker, ^message_id ->
        :ok
      end)

      expect(Core.Trigger, :execute_device_error_triggers, fn ^new_state,
                                                              "invalid_introspection",
                                                              %{
                                                                "base64_payload" => base64_payload
                                                              },
                                                              ^timestamp ->
        assert base64_payload == Base.encode64(payload)
        :ok
      end)

      expect(Core.DataHandler, :update_stats, fn ^new_state, "", nil, "", ^payload ->
        :ok
      end)

      IntrospectionHandler.handle_introspection(state, payload, message_id, timestamp)
    end
  end

  describe "Introspection integration test" do
    property "processes introspection correctly", test_context do
      %{device: device, interfaces: interfaces, realm_name: realm_name} =
        test_context

      check all interfaces <- random_interfaces(interfaces),
                introspection <- gen_introspection(interfaces),
                time <- Astarte.Common.Generators.Timestamp.timestamp() do
        DataUpdater.handle_introspection(
          realm_name,
          device.encoded_id,
          introspection,
          gen_tracking_id(),
          time
        )

        # WARNING: This test assumes that the introspection is processed immediately.
        # Which does not hold true but it seems to be working anyway.
        # This may lead to race conditions
        state = DataUpdater.dump_state(realm_name, device.encoded_id)

        assert interfaces_to_introspection(interfaces) == state.introspection
      end
    end
  end

  defp gen_introspection(interfaces) do
    repeatedly(fn ->
      interfaces
      |> Enum.map(fn interface ->
        "#{interface.name}:#{interface.major_version}:#{interface.minor_version}"
      end)
      |> Enum.join(";")
    end)
  end

  defp random_interfaces(interfaces) do
    repeatedly(fn ->
      n = 1..length(interfaces) |> Enum.random()

      interfaces
      |> Enum.take_random(n)
    end)
  end

  defp interfaces_to_introspection(interfaces) do
    Map.new(interfaces, &{&1.name, &1.major_version})
  end
end
