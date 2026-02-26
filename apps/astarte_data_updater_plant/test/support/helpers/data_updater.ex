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

defmodule Astarte.Helpers.DataUpdater do
  @moduledoc """
  Helper functions for testing the DataUpdater module.
  """

  import Mimic
  import ExUnit.Callbacks

  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Mississippi.Consumer.DataUpdater
  alias Mississippi.Consumer.MessageTracker
  alias Mississippi.Producer.EventsProducer

  @max_rand trunc(:math.pow(2, 32) - 1)

  def setup_data_updater(realm_name, device_id) do
    sharding_key = {realm_name, device_id}

    # start data_updater with default impl so that it doesn't perform queries
    data_updater = start_supervised!({DataUpdater, sharding_key: sharding_key})

    # allow the data updater pid
    allow_data_updater(data_updater)

    # manually initialize the handler state
    {:ok, handler_state} = Impl.init(sharding_key)

    # this is a hack, it should be exposed as an option by mississippi
    :sys.replace_state(data_updater, fn state ->
      %{state | message_handler: Impl, handler_state: handler_state}
    end)

    data_updater
  end

  def allow_data_updater(data_updater) do
    allow(Astarte.DataAccess.Config, self(), data_updater)
    allow(Impl, self(), data_updater)
    :ok
  end

  def mississippi_producer_opts! do
    [
      amqp_producer_options: [host: Config.amqp_consumer_host!()],
      mississippi_config: [
        queues: [
          prefix: Config.data_queue_prefix!(),
          total_count: Config.data_queue_total_count!()
        ]
      ]
    ]
  end

  def install_volatile_trigger(
        realm,
        encoded_device_id,
        parent_id,
        trigger_id,
        simple_trigger,
        trigger_target
      ) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    signal =
      {:install_volatile_trigger, parent_id, trigger_id, simple_trigger, trigger_target}

    get_data_updater_process!(realm, device_id)
    |> DataUpdater.handle_signal(signal)
  end

  def delete_volatile_trigger(realm, encoded_device_id, trigger_id) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    get_data_updater_process!(realm, device_id)
    |> DataUpdater.handle_signal({:delete_volatile_trigger, trigger_id})
  end

  def handle_connection(realm, encoded_device_id, ip, timestamp) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    headers =
      headers_fixture(realm, encoded_device_id,
        x_astarte_msg_type: "connection",
        x_astarte_remote_ip: ip
      )

    publish_opts = [
      headers: headers,
      message_id: generate_message_id(realm, encoded_device_id, timestamp),
      timestamp: timestamp,
      sharding_key: {realm, device_id}
    ]

    :ok = ensure_publish("", publish_opts, realm, device_id)
  end

  def handle_introspection(realm, encoded_device_id, introspection, timestamp) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    headers = headers_fixture(realm, encoded_device_id, x_astarte_msg_type: "introspection")

    publish_opts = [
      headers: headers,
      message_id: generate_message_id(realm, encoded_device_id, timestamp),
      timestamp: timestamp,
      sharding_key: {realm, device_id}
    ]

    :ok = ensure_publish(introspection, publish_opts, realm, device_id)
  end

  def handle_data(realm, encoded_device_id, interface, path, value, timestamp) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    headers =
      headers_fixture(realm, encoded_device_id,
        x_astarte_msg_type: "data",
        x_astarte_interface: interface,
        x_astarte_path: path
      )

    publish_opts = [
      headers: headers,
      message_id: generate_message_id(realm, encoded_device_id, timestamp),
      timestamp: timestamp,
      sharding_key: {realm, device_id}
    ]

    :ok = ensure_publish(value, publish_opts, realm, device_id)
  end

  def handle_control(realm, encoded_device_id, control_path, value, timestamp) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    headers =
      headers_fixture(realm, encoded_device_id,
        x_astarte_msg_type: "control",
        x_astarte_control_path: control_path
      )

    publish_opts = [
      headers: headers,
      message_id: generate_message_id(realm, encoded_device_id, timestamp),
      timestamp: timestamp,
      sharding_key: {realm, device_id}
    ]

    :ok = ensure_publish(value, publish_opts, realm, device_id)
  end

  def handle_disconnection(realm, encoded_device_id, timestamp) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    headers = headers_fixture(realm, encoded_device_id, x_astarte_msg_type: "disconnection")

    publish_opts = [
      headers: headers,
      message_id: generate_message_id(realm, encoded_device_id, timestamp),
      timestamp: timestamp,
      sharding_key: {realm, device_id}
    ]

    :ok = ensure_publish("", publish_opts, realm, device_id)
  end

  def handle_internal(realm, encoded_device_id, internal_path, value, timestamp) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    headers =
      headers_fixture(realm, encoded_device_id,
        x_astarte_msg_type: "internal",
        x_astarte_internal_path: internal_path
      )

    publish_opts = [
      headers: headers,
      message_id: generate_message_id(realm, encoded_device_id, timestamp),
      timestamp: timestamp,
      sharding_key: {realm, device_id}
    ]

    :ok = ensure_publish(value, publish_opts, realm, device_id)
  end

  def handle_heartbeat(realm, encoded_device_id, timestamp) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    headers = headers_fixture(realm, encoded_device_id, x_astarte_msg_type: "heartbeat")

    publish_opts = [
      headers: headers,
      message_id: generate_message_id(realm, encoded_device_id, timestamp),
      timestamp: timestamp,
      sharding_key: {realm, device_id}
    ]

    :ok = ensure_publish("", publish_opts, realm, device_id)
  end

  def start_device_deletion(realm, encoded_device_id, timestamp) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    get_data_updater_process!(realm, device_id)
    |> DataUpdater.handle_signal({:start_device_deletion, timestamp})
  end

  defp ensure_publish(payload, opts, realm, device_id) do
    {:ok, message_tracker} = MessageTracker.get_message_tracker({realm, device_id})
    me = self()

    MessageTracker
    |> allow(self(), get_data_updater_process!(realm, device_id))
    |> expect(:ack_delivery, fn ^message_tracker, message ->
      result = MessageTracker.ack_delivery(message_tracker, message)
      send(me, :ack_delivery)
      result
    end)

    :ok = EventsProducer.publish(payload, opts)

    receive do
      :ack_delivery -> :ok
    after
      1000 -> raise "No message received"
    end
  end

  def dump_state(realm, encoded_device_id) do
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    get_data_updater_process!(realm, device_id)
    |> DataUpdater.handle_signal(:dump_state)
  end

  def get_data_updater_process!(realm, device_id) do
    {:ok, pid} = DataUpdater.get_data_updater_process({realm, device_id})
    pid
  end

  defp headers_fixture(realm, encoded_device_id, opts) do
    fixture = [
      x_astarte_vmqamqp_proto_ver: 1,
      x_astarte_realm: realm,
      x_astarte_device_id: encoded_device_id
    ]

    Keyword.merge(fixture, opts)
  end

  defp generate_message_id(realm, device_id, timestamp) do
    realm_trunc = String.slice(realm, 0..63)
    device_id_trunc = String.slice(device_id, 0..15)
    timestamp_hex_str = Integer.to_string(timestamp, 16)
    rnd = Enum.random(0..@max_rand) |> Integer.to_string(16)

    "#{realm_trunc}-#{device_id_trunc}-#{timestamp_hex_str}-#{rnd}"
  end
end
