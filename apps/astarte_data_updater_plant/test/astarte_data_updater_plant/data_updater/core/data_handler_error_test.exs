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

defmodule UnexpectedValueType do
  defstruct []
end

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.DataHandlerErrorTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties
  use Mimic

  alias Astarte.Core.Mapping.ValueType
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.DataHandler
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  import Astarte.Helpers.DataUpdater
  import Astarte.InterfaceUpdateGenerators

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state}
  end

  describe "handle_data/6 errors with" do
    test "an invalid interface", context do
      %{state: state, interfaces: interfaces} = context

      # Invalid String.t()
      invalid_name = <<0xFFFF::16>>

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        context =
        gen_context(state, interfaces)
        |> Enum.at(0)
        |> Map.put(:interface, invalid_name)

      expect(Core.Error, :handle_error, fn ^context, _error, [update_stats: false] ->
        state
      end)

      assert ^state =
               DataHandler.handle_data(state, interface, path, payload, message_id, timestamp)
    end

    test "an invalid path", context do
      %{state: state, interfaces: interfaces} = context

      # Invalid String.t()
      invalid_path = <<0xFFFF::16>>

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        context =
        gen_context(state, interfaces)
        |> Enum.at(0)
        |> Map.put(:path, invalid_path)

      expect(Core.Error, :handle_error, fn ^context, _error -> state end)

      assert ^state =
               DataHandler.handle_data(state, interface, path, payload, message_id, timestamp)
    end

    test "an invalid doublke-slashed path", test_context do
      %{state: state, interfaces: interfaces} = test_context

      # Double slashed invalid path
      invalid_path = "//invalid"

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        context =
        gen_context(state, interfaces)
        |> Enum.at(0)
        |> Map.put(:path, invalid_path)

      expect(Core.Error, :handle_error, fn ^context, _error -> state end)

      assert ^state =
               DataHandler.handle_data(
                 state,
                 interface,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end

    test "a cache miss", test_context do
      %{state: state, interfaces: interfaces} = test_context

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        context =
        gen_context(state, interfaces)
        |> Enum.at(0)

      expect(Core.Error, :handle_error, fn ^context, _error -> state end)

      expect(Core.Interface, :maybe_handle_cache_miss, fn nil, ^interface, ^state ->
        {:error, :interface_loading_failed}
      end)

      assert ^state =
               DataHandler.handle_data(
                 state,
                 interface,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end

    test "on server owned interfaces", test_context do
      %{state: state, interfaces: interfaces} = test_context

      server_owned_interfaces =
        interfaces
        |> Enum.filter(&(&1.ownership == :server))

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        gen_context(state, server_owned_interfaces)
        |> Enum.at(0)

      {:ok, _descriptor, new_state} =
        Core.Interface.maybe_handle_cache_miss(nil, interface, state)

      expect(Core.Error, :handle_error, fn context, _error -> context.state end)

      assert ^new_state =
               DataHandler.handle_data(
                 state,
                 interface,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end

    test "on mappings not found", test_context do
      %{state: state, interfaces: interfaces} = test_context

      device_owned_interfaces =
        interfaces
        |> Enum.filter(&(&1.ownership == :device))

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        gen_context(state, device_owned_interfaces)
        |> Enum.at(0)

      {:ok, descriptor, new_state} =
        Core.Interface.maybe_handle_cache_miss(nil, interface, state)

      mappings = new_state.mappings

      expect(Core.Interface, :resolve_path, fn ^path, ^descriptor, ^mappings ->
        {:error, :mapping_not_found}
      end)

      expect(Core.Error, :handle_error, fn context, _error -> context.state end)

      assert ^new_state =
               DataHandler.handle_data(
                 state,
                 interface,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end

    test "on guessed endpoints", test_context do
      %{state: state, interfaces: interfaces} = test_context

      device_owned_interfaces =
        interfaces
        |> Enum.filter(&(&1.ownership == :device))

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        gen_context(state, device_owned_interfaces)
        |> Enum.at(0)

      {:ok, descriptor, new_state} =
        Core.Interface.maybe_handle_cache_miss(nil, interface, state)

      mappings = new_state.mappings

      expect(Core.Interface, :resolve_path, fn ^path, ^descriptor, ^mappings ->
        {:guessed, :non_relevant}
      end)

      expect(Core.Error, :handle_error, fn context, _error -> context.state end)

      assert ^new_state =
               DataHandler.handle_data(
                 state,
                 interface,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end

    test "if the payload is not decodable", test_context do
      %{state: state, interfaces: interfaces} = test_context

      device_owned_interfaces =
        interfaces
        |> Enum.filter(&(&1.ownership == :device))

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        gen_context(state, device_owned_interfaces)
        |> Enum.at(0)

      {:ok, _descriptor, new_state} =
        Core.Interface.maybe_handle_cache_miss(nil, interface, state)

      expect(PayloadsDecoder, :decode_bson_payload, fn ^payload, ^timestamp ->
        {:error, :undecodable_bson_payload}
      end)

      expect(Core.Error, :handle_error, fn context, _error -> context.state end)

      assert ^new_state =
               DataHandler.handle_data(
                 state,
                 interface,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end

    test "if an unexpected value type is supplied", test_context do
      %{state: state, interfaces: interfaces} = test_context

      device_owned_interfaces =
        interfaces
        |> Enum.filter(&(&1.ownership == :device))

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        gen_context(state, device_owned_interfaces)
        |> Enum.at(0)

      {:ok, _descriptor, new_state} =
        Core.Interface.maybe_handle_cache_miss(nil, interface, state)

      expect(PayloadsDecoder, :decode_bson_payload, fn ^payload, ^timestamp ->
        {%UnexpectedValueType{}, DateTime.utc_now(), nil}
      end)

      expect(Core.Error, :handle_error, fn context, _error -> context.state end)

      assert ^new_state =
               DataHandler.handle_data(
                 state,
                 interface,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end

    test "if an unexpected key is in the value", test_context do
      %{state: state, interfaces: interfaces} = test_context

      device_owned_interfaces =
        interfaces
        |> Enum.filter(&(&1.ownership == :device))

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        gen_context(state, device_owned_interfaces)
        |> Enum.at(0)

      {:ok, _descriptor, new_state} =
        Core.Interface.maybe_handle_cache_miss(nil, interface, state)

      expect(PayloadsDecoder, :decode_bson_payload, fn ^payload, ^timestamp ->
        {%{"an_unexpected_key" => nil}, DateTime.utc_now(), nil}
      end)

      expect(Core.Error, :handle_error, fn context, _error -> context.state end)

      assert ^new_state =
               DataHandler.handle_data(
                 state,
                 interface,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end

    test "if the payload is too big", test_context do
      %{state: state, interfaces: interfaces} = test_context

      device_owned_interfaces =
        interfaces
        |> Enum.filter(&(&1.ownership == :device))

      %{
        state: state,
        interface: interface,
        message_id: message_id,
        path: path,
        timestamp: timestamp,
        payload: payload
      } =
        gen_non_empty_value_context(state, device_owned_interfaces)
        |> Enum.at(0)

      {:ok, _descriptor, new_state} =
        Core.Interface.maybe_handle_cache_miss(nil, interface, state)

      expect(ValueType, :validate_value, fn _, value ->
        {payload_value, _, _} =
          PayloadsDecoder.decode_bson_payload(payload, DateTime.utc_now(:millisecond))

        assert valid_value?(payload_value, value)

        {:error, :value_size_exceeded}
      end)

      expect(Core.Error, :handle_error, fn context, _error -> context.state end)

      assert ^new_state =
               DataHandler.handle_data(
                 state,
                 interface,
                 path,
                 payload,
                 message_id,
                 timestamp
               )
    end
  end

  defp gen_non_empty_value_context(state, interfaces) do
    gen all interface <- member_of(interfaces),
            message_id <- repeatedly(&gen_message_id/0),
            update <- valid_mapping_update_for(interface) |> filter(&(&1.value != %{})),
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

  defp valid_value?(%DateTime{} = payload_value, %DateTime{} = value),
    do: DateTime.compare(payload_value, value) == :eq

  defp valid_value?(%{} = payload_value, value) do
    payload_value == value || payload_value |> Map.values() |> Enum.any?(&valid_value?(&1, value))
  end

  defp valid_value?(payload_value, value), do: payload_value == value
end
