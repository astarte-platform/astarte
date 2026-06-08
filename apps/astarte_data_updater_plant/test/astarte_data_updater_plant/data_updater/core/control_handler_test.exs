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

  use Astarte.Cases.DataUpdater

  use Mimic

  import ExUnit.CaptureLog

  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.ControlHandler
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock

  setup do
    Mox.verify_on_exit!()
  end

  setup do
    header = 0
    payload = System.unique_integer() |> to_string()
    decoded_payload = System.unique_integer() |> to_string()
    encoded_payload = <<header::size(32), payload::binary>>

    %{
      header: header,
      payload: payload,
      encoded_payload: encoded_payload,
      decoded_payload: decoded_payload
    }
  end

  test "discards messages if discards_messages is enabled", context do
    %{state: state} = context
    state = %{state | discard_messages: true}

    {action, _result, new_state} =
      ControlHandler.handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, 0)

    assert action == :discard
    assert new_state == state
  end

  describe "/emptyCache" do
    test "sets the pending empty cache and acks the message", context do
      %{state: state} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      assert {:ack, _result, _new_state} =
               ControlHandler.handle_control(state, "/emptyCache", "", 0)
    end

    test "discrads the message if the device session is not found", context do
      %{state: state} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:ok, %{local_matches: 0, remote_matches: 0}}
      end)

      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "device_session_not_found",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/emptyCache", "", 0)

      assert {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards the message if interface loading fails", context do
      %{state: state} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      expect(Core.Device, :resend_all_properties, fn _state ->
        {:error, :sending_properties_to_interface_failed}
      end)

      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "resend_interface_properties_failed",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/emptyCache", "", 0)

      {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end

    test "discards the message for other errors", context do
      %{state: state} = context

      Mox.expect(ClientMock, :publish, fn _data ->
        {:error, :reason}
      end)

      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)

      expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                              "empty_cache_error",
                                                              _meta,
                                                              _ts ->
        :ok
      end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/emptyCache", "", 0)

      {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end

  describe "/producer/properties" do
    test "prunes all device properties with payload = <<0, 0, 0, 0>>", context do
      %{state: state} = context

      expect(Core.Device, :prune_device_properties, fn _state, "", _timestamp -> :ok end)

      {action, _result, new_state} =
        ControlHandler.handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, 0)

      assert action == :ack
      assert new_state.total_received_msgs > state.total_received_msgs
    end

    test "prunes the device properties with the deflated zlib payload", context do
      %{
        state: state,
        payload: payload,
        encoded_payload: encoded_payload,
        decoded_payload: decoded_payload
      } = context

      expect(Core.Device, :prune_device_properties, fn _state, ^decoded_payload, _timestamp ->
        :ok
      end)

      expect(PayloadsDecoder, :safe_inflate, fn ^payload -> {:ok, decoded_payload} end)

      {action, _result, new_state} =
        ControlHandler.handle_control(state, "/producer/properties", encoded_payload, 0)

      assert action == :ack
      assert new_state.total_received_msgs > state.total_received_msgs
    end

    test "asks a clean session for invalid zlib payload", context do
      %{
        state: state,
        payload: payload,
        encoded_payload: encoded_payload
      } = context

      expect(Core.Device, :ask_clean_session, fn _state, _timestamp -> {:ok, state} end)
      expect(PayloadsDecoder, :safe_inflate, fn ^payload -> :error end)

      assert {:discard, _result, new_state, {:continue, continue_arg}} =
               ControlHandler.handle_control(state, "/producer/properties", encoded_payload, 0)

      {:ok, _} = Impl.handle_continue(continue_arg, new_state)
    end
  end

  test "unexpected messages are discarded and the device is asked a clean session", context do
    %{state: state} = context

    expect(Core.Device, :ask_clean_session, fn state, _timestamp -> {:ok, state} end)

    expect(Core.Trigger, :execute_device_error_triggers, fn _state,
                                                            "unexpected_control_message",
                                                            _meta,
                                                            _ts ->
      :ok
    end)

    assert {{action, _result, new_state, {:continue, continue_arg}}, log} =
             with_log(fn ->
               ControlHandler.handle_control(state, "/invalid/path", <<>>, 0)
             end)

    {:ok, new_state} = Impl.handle_continue(continue_arg, new_state)

    assert action == :discard
    assert log =~ "Unexpected control"
    assert new_state.total_received_msgs > state.total_received_msgs
  end
end
