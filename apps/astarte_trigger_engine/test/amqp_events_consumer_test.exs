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
  use ExUnit.Case, async: false
  import Mox
  alias Astarte.TriggerEngine.AMQPEventsConsumer
  alias Astarte.TriggerEngine.Config
  alias AMQP.{Basic, Channel, Connection}
  alias Astarte.TriggerEngine.DatabaseTestHelper

  @payload "some_payload"
  @payload2 "some_other_payload"
  @headers [
    one: "header",
    another: "different header",
    number: 42,
    x_astarte_realm: DatabaseTestHelper.test_realm(),
    x_astarte_trigger_policy: "apolicy"
  ]
  @headers2 [
    different: "headers",
    anothernumber: 100,
    x_astarte_realm: DatabaseTestHelper.test_realm(),
    x_astarte_trigger_policy: "anotherpolicy"
  ]

  setup_all do
    :ok = DatabaseTestHelper.create_db()
    :ok = DatabaseTestHelper.populate_policies_db()
    :timer.sleep(1000)

    on_exit(fn ->
      DatabaseTestHelper.drop_db()
    end)
  end

  describe "AMQP message consuming" do
    setup [:set_mox_global, :create_and_drop_amqp]

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
      |> expect(:consume, 2, fn _, _ ->
        :ok
      end)

      assert :ok == produce_event(chan, @payload, @headers, "message1")
      assert :ok == produce_event(chan, @payload2, @headers2, "message2")
      # Leave time for the consumer to ack
      :timer.sleep(1000)
    end

    test "different policy headers lead to different policy processes", %{chan: chan} do
      map_headers =
        Enum.reduce(@headers, %{}, fn {k, v}, acc ->
          Map.put(acc, to_string(k), v)
        end)

      map_headers2 =
        Enum.reduce(@headers2, %{}, fn {k, v}, acc ->
          Map.put(acc, to_string(k), v)
        end)

      MockEventsConsumer
      |> expect(:consume, 2, fn _, _ ->
        :ok
      end)

      assert :ok == produce_event(chan, @payload, @headers, "message1")
      assert :ok == produce_event(chan, @payload2, @headers2, "message2")
      # Leave time for the consumer to ack
      :timer.sleep(1000)

      registered_policies =
        Registry.select(Registry.PolicyRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

      assert [
               {DatabaseTestHelper.test_realm(), "apolicy"},
               {DatabaseTestHelper.test_realm(), "anotherpolicy"}
             ]
             |> Enum.map(fn e -> Enum.member?(registered_policies, e) end)
    end
  end

  defp create_and_drop_amqp(_context) do
    {conn, chan} = create_amqp_conn_and_chan()

    on_exit(fn -> drop_amqp_chan_and_conn(chan, conn) end)

    {:ok, chan: chan}
  end

  defp create_amqp_conn_and_chan() do
    :ok = wait_for_connection()

    amqp_consumer_options = Config.amqp_consumer_options!()

    {:ok, conn} = Connection.open(amqp_consumer_options)

    {:ok, chan} = Channel.open(conn)

    {conn, chan}
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

  defp produce_event(chan, payload, headers, message_id) do
    exchange = Config.events_exchange_name!()
    routing_key = Config.events_routing_key!()

    Basic.publish(chan, exchange, routing_key, payload, headers: headers, message_id: message_id)
  end

  defp drop_amqp_chan_and_conn(chan, conn) do
    Channel.close(chan)
    Connection.close(conn)
  end
end
