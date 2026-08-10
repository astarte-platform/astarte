#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.VMQ.Plugin.RPCTest do
  use ExUnit.Case, async: true

  alias Astarte.VMQ.Plugin.Test.Fixtures.Topic, as: TopicFixture
  alias Astarte.VMQ.Plugin.Test.Helpers.Device, as: DeviceHelper
  alias Astarte.VMQ.Plugin.Test.Helpers.PayloadGenerator
  alias Astarte.VMQ.Plugin.Test.Helpers.TopicGenerator

  alias Astarte.VMQ.Plugin.MockVerne

  use ExUnitProperties
  import Mox

  setup_all do
    MockVerne.start_link()

    %{
      rpc_server: {:via, Horde.Registry, {Registry.VMQPluginRPC, :server}}
    }
  end

  test "the rpc server is a child of the rpc supervisor", %{rpc_server: server} do
    pid = GenServer.whereis(server)
    children = Horde.DynamicSupervisor.which_children(Astarte.VMQ.Plugin.RPC.Supervisor)

    assert [{_id, ^pid, _type, _modules}] = children
  end

  describe "Publish call" do
    test "fails on empty topic", %{rpc_server: server} do
      data =
        %{
          topic_tokens: [],
          payload: "some data",
          qos: 2
        }

      assert {:error, :empty_topic_tokens} = GenServer.call(server, {:publish, data})

      assert MockVerne.consume_message() == nil
    end

    property "fails on invalid qos", %{rpc_server: server} do
      check all invalid_qos <- invalid_qos() do
        data =
          %{
            topic_tokens: TopicFixture.valid_topic(),
            payload: "some data",
            qos: invalid_qos
          }

        assert {:error, :invalid_qos} = GenServer.call(server, {:publish, data})

        assert MockVerne.consume_message() == nil
      end
    end

    property "succeeds on valid call", %{rpc_server: server} do
      check all valid_topic <- topic_tokens(),
                payload <- PayloadGenerator.payload(),
                qos <- integer(0..2) do
        data =
          %{
            topic_tokens: valid_topic,
            payload: payload,
            qos: qos
          }

        assert {:ok, _} = GenServer.call(server, {:publish, data})

        assert MockVerne.consume_message() == {valid_topic, payload, %{qos: qos}}
      end
    end
  end

  describe "Disconnect call" do
    test "fails on empty client id", %{rpc_server: server} do
      assert {:error, :empty_client_id} = GenServer.call(server, {:disconnect, %{client_id: nil}})

      assert MockVerne.consume_message() == nil
    end

    test "fails on empty discard_state", %{rpc_server: server} do
      assert {:error, :empty_discard_state} =
               GenServer.call(server, {:disconnect, %{discard_state: nil}})

      assert MockVerne.consume_message() == nil
    end

    test "succeeds when the device exists", %{rpc_server: server} do
      realm_name = "test_#{System.unique_integer()}"
      device_id = DeviceHelper.random_device()
      client_id = "#{realm_name}/#{device_id}"

      MockVerneMQ.API
      |> allow(self(), server)
      |> expect(:disconnect_by_subscriber_id, fn _, _ -> :ok end)

      assert :ok =
               GenServer.call(
                 server,
                 {:disconnect, %{client_id: client_id, discard_state: :do_cleanup}}
               )

      assert MockVerne.consume_message() == nil
    end

    test "fails when the device does not exist", %{rpc_server: server} do
      realm_name = "test_#{System.unique_integer()}"
      device_id = DeviceHelper.random_device()
      client_id = "#{realm_name}/#{device_id}"

      MockVerneMQ.API
      |> allow(self(), server)
      |> expect(:disconnect_by_subscriber_id, fn _, _ -> :not_found end)

      assert {:error, :not_found} =
               GenServer.call(
                 server,
                 {:disconnect, %{client_id: client_id, discard_state: :do_cleanup}}
               )

      assert MockVerne.consume_message() == nil
    end
  end

  defp topic_tokens, do: TopicGenerator.mqtt_topic() |> map(&String.split(&1, "/"))
  defp invalid_qos, do: float(min: 3) |> map(&floor/1)
end
