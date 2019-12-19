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

defmodule Astarte.TriggerEngine.AMQPEventsConsumerTest do
  use ExUnit.Case
  import Mox
  alias Astarte.TriggerEngine.AMQPEventsConsumer
  alias Astarte.TriggerEngine.Config
  alias AMQP.{Basic, Channel, Connection}

  @payload "some_payload"
  @payload2 "some_other_payload"
  @headers [one: "header", another: "different header", number: 42]
  @headers2 [different: "headers", anothernumber: 100]

  setup_all do
    :ok = wait_for_connection()

    {:ok, conn} = Connection.open(Config.amqp_consumer_options())
    {:ok, chan} = Channel.open(conn)

    {:ok, chan: chan}
  end

  describe "AMQP message consuming" do
    setup :set_mox_global

    test "calls EventsConsumer when receiving an event", %{chan: chan} do
      map_headers =
        Enum.reduce(@headers, %{}, fn {k, v}, acc ->
          Map.put(acc, to_string(k), v)
        end)

      map_headers2 =
        Enum.reduce(@headers2, %{}, fn {k, v}, acc ->
          Map.put(acc, to_string(k), v)
        end)

      MockEventsConsumer
      |> expect(:consume, fn payload, headers ->
        assert payload == @payload
        assert is_map(headers)
        assert headers == map_headers
      end)
      |> expect(:consume, fn payload, headers ->
        assert payload == @payload2
        assert is_map(headers)
        assert headers == map_headers2
      end)

      assert :ok == produce_event(chan, @payload, @headers)
      assert :ok == produce_event(chan, @payload2, @headers2)
      # Leave time for the consumer to ack
      :timer.sleep(1000)
    end
  end

  defp wait_for_connection(retry_count \\ 0)

  # Avoid endless waiting (retry_count > 50 ~= 5 seconds)
  defp wait_for_connection(retry_count) when retry_count > 50 do
    {:error, :not_connected}
  end

  defp wait_for_connection(retry_count) do
    %{channel: chan} = :sys.get_state(AMQPEventsConsumer)

    if chan do
      :ok
    else
      :timer.sleep(100)
      wait_for_connection(retry_count + 1)
    end
  end

  defp produce_event(chan, payload, headers) do
    exchange = Config.events_exchange_name()
    routing_key = Config.events_routing_key()

    Basic.publish(chan, exchange, routing_key, payload, headers: headers)
  end
end
