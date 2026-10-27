#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin.Connection.SynchronizerTest do
  use ExUnit.Case

  alias AMQP.{Channel, Connection, Queue}
  alias Astarte.VMQ.Plugin.Config
  alias Astarte.VMQ.Plugin.Connection.Synchronizer
  alias Astarte.VMQ.Plugin.Connection.Synchronizer.Supervisor, as: SynchronizerSupervisor

  @device_id :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  @realm "test"
  @device_base_path "#{@realm}/#{@device_id}"

  setup_all do
    amqp_opts = Config.amqp_options()
    {:ok, conn} = Connection.open(amqp_opts)
    {:ok, chan} = Channel.open(conn)
    queue_total = Config.mississippi_opts!()[:mississippi_config][:queues][:total_count]

    queues =
      for n <- 0..queue_total do
        queue_name = "#{Config.data_queue_prefix()}#{n}"
        {:ok, _} = Queue.declare(chan, queue_name, durable: true)
        queue_name
      end

    {:ok, chan: chan, queues: queues}
  end

  setup %{chan: chan, queues: queues} do
    test_pid = self()

    consumer_tags =
      for queue <- queues do
        {:ok, consumer_tag} =
          Queue.subscribe(chan, queue, fn payload, meta ->
            send(test_pid, {:amqp_msg, payload, meta})
          end)

        consumer_tag
      end

    on_exit(fn ->
      Enum.each(consumer_tags, fn consumer_tag ->
        Queue.unsubscribe(chan, consumer_tag)
      end)
    end)

    :ok
  end

  test "Standard connection flow" do
    connection_timestamp = now_us_x10_timestamp()

    # no reconciler
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # start the reconciler
    reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             [
               {reconciler_pid, nil}
             ]

    # connect the device
    Synchronizer.handle_connection(reconciler_pid, connection_timestamp)

    # Make sure messages arrived
    Process.sleep(100)

    # the reconciler should be dead by now
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    assert_receive {:amqp_msg, "",
                    %{headers: connection_headers, timestamp: ^connection_timestamp}}

    assert %{"x_astarte_msg_type" => "connection"} = amqp_headers_to_map(connection_headers)
  end

  test "Ordered disconnection and reconnection events are correctly ordered" do
    connection_timestamp = now_us_x10_timestamp()
    disconnection_timestamp = connection_timestamp + 1
    reconnection_timestamp = connection_timestamp + 2

    # No reconciler
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # Start the reconciler
    reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             [
               {reconciler_pid, nil}
             ]

    # Connect the device (right now we don't care about concurrency)
    Synchronizer.handle_connection(reconciler_pid, connection_timestamp)

    # Make sure the reconciler is dead by now
    Process.sleep(100)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    assert_receive {:amqp_msg, "",
                    %{headers: connection_headers, timestamp: ^connection_timestamp}}

    assert %{"x_astarte_msg_type" => "connection"} = amqp_headers_to_map(connection_headers)

    # Now, another reconciler comes in hand
    another_reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    # Correctly ordered events: disconnection before reconnection
    # we use async tasks to simulate concurrency because handle_[dis]connection is sync
    Task.start(fn ->
      Synchronizer.handle_disconnection(another_reconciler_pid, disconnection_timestamp)
    end)

    Task.start(fn ->
      Synchronizer.handle_connection(another_reconciler_pid, reconnection_timestamp)
    end)

    # Make sure the other reconciler is dead, too, by now
    Process.sleep(100)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # First, disconnection is received...
    receive do
      disconnect_message ->
        assert {:amqp_msg, "",
                %{
                  headers: disconnection_headers,
                  timestamp: ^disconnection_timestamp
                }} = disconnect_message

        assert %{"x_astarte_msg_type" => "disconnection"} =
                 amqp_headers_to_map(disconnection_headers)
    after
      1_000 -> flunk("Expected disconnection message, did not receive any.")
    end

    # ... and only after, reconnection
    receive do
      reconnect_message ->
        assert {:amqp_msg, "",
                %{
                  headers: connection_headers,
                  timestamp: ^reconnection_timestamp
                }} = reconnect_message

        assert %{
                 "x_astarte_msg_type" => "connection"
               } = amqp_headers_to_map(connection_headers)
    after
      1_000 -> flunk("Expected connection message, did not receive any.")
    end
  end

  test "Disconnection and reconnection events swapped, but near in time, are correctly reordered" do
    connection_timestamp = now_us_x10_timestamp()
    disconnection_timestamp = connection_timestamp + 1
    reconnection_timestamp = connection_timestamp + 2

    # No reconciler
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # Start the reconciler
    reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             [
               {reconciler_pid, nil}
             ]

    # Connect the device (right now we don't care about concurrency)
    Synchronizer.handle_connection(reconciler_pid, connection_timestamp)

    # Make sure the reconciler is dead by now
    Process.sleep(100)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    assert_receive {:amqp_msg, "",
                    %{headers: connection_headers, timestamp: ^connection_timestamp}}

    assert %{"x_astarte_msg_type" => "connection"} = amqp_headers_to_map(connection_headers)

    # Now, another reconciler comes in hand
    another_reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    # Make some strange things à la VMQ, like a connection just before a disconnection
    # we use async tasks to simulate concurrency because handle_[dis]connection is sync
    Task.start(fn ->
      Synchronizer.handle_connection(another_reconciler_pid, reconnection_timestamp)
    end)

    Task.start(fn ->
      Synchronizer.handle_disconnection(another_reconciler_pid, disconnection_timestamp)
    end)

    # Make sure the other reconciler is dead, too, by now
    Process.sleep(100)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # First, disconnection is received...
    receive do
      disconnect_message ->
        assert {:amqp_msg, "",
                %{
                  headers: disconnection_headers,
                  timestamp: ^disconnection_timestamp
                }} = disconnect_message

        assert %{"x_astarte_msg_type" => "disconnection"} =
                 amqp_headers_to_map(disconnection_headers)
    after
      1_000 -> flunk("Expected disconnection message, did not receive any.")
    end

    # ... and only after, reconnection
    receive do
      reconnect_message ->
        assert {:amqp_msg, "",
                %{
                  headers: connection_headers,
                  timestamp: ^reconnection_timestamp
                }} = reconnect_message

        assert %{
                 "x_astarte_msg_type" => "connection"
               } = amqp_headers_to_map(connection_headers)
    after
      1_000 -> flunk("Expected connection message, did not receive any.")
    end
  end

  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp now_us_x10_timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix(:microsecond)
    |> Kernel.*(10)
  end

  defp get_connection_reconciler_process!(client_id) do
    case SynchronizerSupervisor.start_child(client_id: client_id) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
