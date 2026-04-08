#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind srl
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

defmodule AstarteE2E.AmqpDeviceTrigger do
  use GenServer, restart: :temporary
  require Logger

  alias AstarteE2E.Config
  alias AstarteE2E.Device
  alias AstarteE2E.AmqpTriggers.Consumer
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent

  @events [:device_connected]

  @routing_key "e2e_device_triggers"
  @exchange_suffix Config.amqp_trigger_exchange_suffix!()

  def name, do: "AmqpDeviceTrigger"

  def start_link(opts) do
    device_id = Astarte.Core.Device.random_device_id()
    realm = Config.realm!()
    init_arg = opts |> Keyword.merge(device_id: device_id, realm: realm)
    GenServer.start_link(__MODULE__, init_arg)
  end

  @impl true
  def init(opts) do
    realm = Keyword.fetch!(opts, :realm)
    device_id = Keyword.fetch!(opts, :device_id)
    interfaces = Keyword.fetch!(opts, :interfaces)

    state = %{
      device_id: device_id,
      realm: realm,
      interfaces: interfaces,
      messages: nil,
      device_pid: nil,
      consumer_pid: nil
    }

    {:ok, state, {:continue, :install_triggers}}
  end

  @impl true
  def handle_continue(:install_triggers, state) do
    %{
      device_id: device_id,
      realm: realm
    } = state

    case install_triggers(realm, device_id) do
      :ok ->
        Logger.info("Amqp device trigger installed successfully")
        {:noreply, state, {:continue, :start_consumer}}

      {:error, reason} ->
        Logger.error("Failed to install amqp device triggers: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  @impl true
  def handle_continue(:start_consumer, state) do
    me = self()
    message_handler = fn payload, meta -> GenServer.call(me, {:handle_message, payload, meta}) end

    consumer_opts = [
      realm_name: state.realm,
      routing_key: "e2e_device_triggers",
      message_handler: message_handler
    ]

    case Consumer.start_link(consumer_opts) do
      {:ok, consumer_pid} ->
        Logger.info("Device Trigger: consumer started")
        {:noreply, %{state | consumer_pid: consumer_pid}, {:continue, :publish_events}}

      {:error, reason} ->
        Logger.error("Device Trigger: consumer failed to start: #{inspect(reason)}")
        {:stop, {:failed_to_start_consumer, reason}, state}
    end
  end

  @impl true
  def handle_continue(:publish_events, state) do
    %{
      device_id: device_id,
      realm: realm,
      interfaces: interfaces
    } = state

    device_opts = [device_id: device_id, realm: realm, interfaces: interfaces]

    case Device.start_link(device_opts) do
      {:ok, device_pid} ->
        Logger.info("Device started after consumer ready", device_id: device_id)
        {:noreply, %{state | messages: @events, device_pid: device_pid}}

      {:error, reason} ->
        Logger.error("Failed to start device: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  @impl true
  def handle_continue(:stop, state) do
    Consumer.stop(state.consumer_pid)
    {:stop, :normal, state}
  end

  @impl true
  def handle_call({:handle_message, payload, _meta}, _from, state) do
    case SimpleEvent.decode(payload) do
      %SimpleEvent{event: {:device_connected_event, _ev}} ->
        Logger.info("AMQP Device Trigger: device connected",
          device_id: state.device_id
        )

        {:reply, :ok, state, {:continue, :stop}}

      other ->
        Logger.info("AMQP Device Trigger: unexpected event #{inspect(other)}",
          device_id: state.device_id
        )

        {:reply, {:error, :unexpected_trigger}, state}
    end
  end

  def install_triggers(realm, device_id) do
    triggers = generate_triggers(realm, device_id)

    base_url = Config.realm_management_url!()
    astarte_jwt = Config.jwt!()
    url = Path.join([base_url, "v1", realm, "triggers"])

    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"},
      {"Content-Type", "application/json"}
    ]

    triggers
    |> Enum.map(&%{"data" => &1})
    |> Enum.reduce_while(:ok, fn body, :ok ->
      case HTTPoison.post(url, Jason.encode!(body), headers) do
        {:ok, %HTTPoison.Response{status_code: 201}} ->
          {:cont, :ok}

        {:ok, %HTTPoison.Response{status_code: 409}} ->
          Logger.info("Trigger already exists, skipping.")
          {:cont, :ok}

        {:ok, %HTTPoison.Response{status_code: code, body: response_body}} ->
          Logger.warning("Trigger installation failed with status #{code}: #{response_body}")
          {:halt, {:error, %{status: code, body: response_body}}}

        {:error, %HTTPoison.Error{} = error} ->
          Logger.warning("HTTP error while installing trigger: #{inspect(error)}")
          {:halt, {:error, error}}
      end
    end)
  end

  defp generate_triggers(realm, device_id) do
    encoded_device_id = Astarte.Core.Device.encode_device_id(device_id)
    exchange = "astarte_events_#{realm}_#{@exchange_suffix}"

    [
      %{
        "name" => "amqp_device_trigger_#{encoded_device_id}",
        "action" => %{
          "amqp_exchange" => exchange,
          "amqp_routing_key" => @routing_key,
          "amqp_message_expiration_ms" => 100_000,
          "amqp_message_persistent" => false
        },
        "simple_triggers" => [
          %{
            "type" => "device_trigger",
            "on" => "device_connected",
            "device_id" => encoded_device_id
          }
        ]
      }
    ]
  end
end
