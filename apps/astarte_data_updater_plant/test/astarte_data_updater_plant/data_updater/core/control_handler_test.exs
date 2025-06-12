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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.ControlHandlerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Mimic
  import ExUnit.CaptureLog
  import Astarte.Helpers.DataUpdater

  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.ControlHandler
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state, message_tracker: state.message_tracker}
  end

  setup do
    Mox.verify_on_exit!()
  end

  setup do
    message_id = System.unique_integer()
    header = 0
    payload = System.unique_integer() |> to_string()
    decoded_payload = System.unique_integer() |> to_string()
    encoded_payload = <<header::size(32), payload::binary>>

    %{
      message_id: message_id,
      header: header,
      payload: payload,
      encoded_payload: encoded_payload,
      decoded_payload: decoded_payload
    }
  end

  test "discards messages if discards_messages is enabled", context do
    %{state: state, message_tracker: message_tracker, message_id: message_id} = context
    state = %{state | discard_messages: true}

    expect(MessageTracker, :discard, fn ^message_tracker, ^message_id -> :ok end)

    new_state =
      ControlHandler.handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, message_id, 0)

    assert new_state == state
  end

  describe "/emptyCache" do
    test "sets the pending empty cache and acks the message", context do
      %{state: state, message_tracker: message_tracker, message_id: message_id} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      expect(MessageTracker, :ack_delivery, fn ^message_tracker, ^message_id -> :ok end)

      ControlHandler.handle_control(
        state,
        "/emptyCache",
        "",
        message_id,
        0
      )
    end

    test "discrads the message if the device session is not found", context do
      %{state: state, message_tracker: message_tracker, message_id: message_id} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:ok, %{local_matches: 0, remote_matches: 0}}
      end)

      expect(MessageTracker, :discard, fn ^message_tracker, ^message_id -> :ok end)
      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "device_session_not_found",
                                                              _ts ->
        :ok
      end)

      ControlHandler.handle_control(
        state,
        "/emptyCache",
        "",
        message_id,
        0
      )
    end

    test "discards the message if interface loading fails", context do
      %{state: state, message_tracker: message_tracker, message_id: message_id} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      expect(Core.Device, :resend_all_properties, fn _state ->
        {:error, :sending_properties_to_interface_failed}
      end)

      expect(MessageTracker, :discard, fn ^message_tracker, ^message_id -> :ok end)
      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "resend_interface_properties_failed",
                                                              _ts ->
        :ok
      end)

      ControlHandler.handle_control(
        state,
        "/emptyCache",
        "",
        message_id,
        0
      )
    end

    test "discards the message for other errors", context do
      %{state: state, message_tracker: message_tracker, message_id: message_id} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:error, :reason}
      end)

      expect(MessageTracker, :discard, fn ^message_tracker, ^message_id -> :ok end)
      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "empty_cache_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      ControlHandler.handle_control(
        state,
        "/emptyCache",
        "",
        message_id,
        0
      )
    end
  end

  describe "/producer/properties" do
    test "prunes all device properties with payload = <<0, 0, 0, 0>>", context do
      %{state: state, message_tracker: message_tracker, message_id: message_id} = context

      expect(MessageTracker, :ack_delivery, fn ^message_tracker, ^message_id -> :ok end)
      expect(Core.Device, :prune_device_properties, fn _state, "", _timestamp -> :ok end)

      new_state =
        ControlHandler.handle_control(
          state,
          "/producer/properties",
          <<0, 0, 0, 0>>,
          message_id,
          0
        )

      assert new_state.total_received_msgs > state.total_received_msgs
    end

    test "prunes the device properties with the deflated zlib payload", context do
      %{
        state: state,
        message_tracker: message_tracker,
        message_id: message_id,
        payload: payload,
        encoded_payload: encoded_payload,
        decoded_payload: decoded_payload
      } = context

      expect(MessageTracker, :ack_delivery, fn ^message_tracker, ^message_id -> :ok end)

      expect(Core.Device, :prune_device_properties, fn _state, ^decoded_payload, _timestamp ->
        :ok
      end)

      expect(PayloadsDecoder, :safe_inflate, fn ^payload -> {:ok, decoded_payload} end)

      new_state =
        ControlHandler.handle_control(
          state,
          "/producer/properties",
          encoded_payload,
          message_id,
          0
        )

      assert new_state.total_received_msgs > state.total_received_msgs
    end

    test "asks a clean session for invalid zlib payload", context do
      %{
        state: state,
        message_tracker: message_tracker,
        message_id: message_id,
        payload: payload,
        encoded_payload: encoded_payload
      } = context

      expect(MessageTracker, :discard, fn ^message_tracker, ^message_id -> :ok end)
      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)
      expect(PayloadsDecoder, :safe_inflate, fn ^payload -> :error end)

      ControlHandler.handle_control(
        state,
        "/producer/properties",
        encoded_payload,
        message_id,
        0
      )
    end
  end

  test "unexpected messages are discarded and the device is asked a clean session", context do
    %{state: state, message_tracker: message_tracker, message_id: message_id} = context

    expect(Core.Device, :ask_clean_session, fn state, _timestamp -> {:ok, state} end)

    expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                            "unexpected_control_message",
                                                            _meta,
                                                            _ts ->
      :ok
    end)

    expect(MessageTracker, :discard, fn ^message_tracker, ^message_id -> :ok end)

    {new_state, log} =
      with_log(fn ->
        ControlHandler.handle_control(state, "/invalid/path", <<>>, message_id, 0)
      end)

    assert log =~ "Unexpected control"
    assert new_state.total_received_msgs > state.total_received_msgs
  end
end
