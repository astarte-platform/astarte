#mqp
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
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
