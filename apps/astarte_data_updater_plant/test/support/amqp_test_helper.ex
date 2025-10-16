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

defmodule Astarte.DataUpdaterPlant.AMQPTestHelper do
  use GenServer
  require Logger

  def start_link(args) do
    name = Keyword.get(args, :name)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def start_events_consumer(args) do
    Astarte.DataUpdaterPlant.AMQPTestEventsConsumer.start_link(args)
  end

  def init(args) do
    {:ok, %{realm: Keyword.get(args, :realm)}}
  end

  def amqp_consumer_options() do
    Application.get_env(:astarte_data_updater_plant, :amqp_consumer_options, [])
  end

  def events_exchange_name(id) do
    "astarte_events_#{id}"
  end

  def events_queue_name(id) do
    "test_events_#{id}"
  end

  def events_routing_key(id) do
    "test_events_#{id}"
  end

  def events_routing_key() do
    "test_events"
  end

  def notify_deliver(name, payload, headers_map, other_meta) do
    message = {payload, Enum.into(headers_map, %{}), other_meta}
    GenServer.call(name, {:notify_deliver, message})
  end

  def wait_and_get_message(name) do
    GenServer.call(name, :wait_and_get_message)
  end

  def wait_and_get_message() do
    GenServer.call(AMQPTestHelper, :wait_and_get_message)
  end

  def awaiting_messages_count(name) do
    GenServer.call(name, :awaiting_messages_count)
  end

  def clean_queue(name) do
    GenServer.call(name, :clean_queue)
  end

  def clean_queue() do
    GenServer.call(AMQPTestHelper, :clean_queue)
  end

  def handle_call(:wait_and_get_message, from, state) do
    if Map.get(state, :messages) do
      [oldest_message | messages] = state[:messages]

      new_state =
        if messages != [] do
          Map.put(state, :messages, messages)
        else
          Map.delete(state, :messages)
        end

      {:reply, oldest_message, new_state}
    else
      new_state = Map.put(state, :caller, from)
      {:noreply, new_state}
    end
  end

  def handle_call({:notify_deliver, message}, _from, state) do
    new_state =
      if Map.get(state, :caller) do
        GenServer.reply(state[:caller], message)
        Map.delete(state, :caller)
      else
        messages = Map.get(state, :messages, [])
        Map.put(state, :messages, messages ++ [message])
      end

    {:reply, :ok, new_state}
  end

  def handle_call(:awaiting_messages_count, _from, state) do
    count =
      Map.get(state, :messages, [])
      |> length()

    {:reply, count, state}
  end

  def handle_call(:clean_queue, _from, _state) do
    {:reply, :ok, %{}}
  end
end
