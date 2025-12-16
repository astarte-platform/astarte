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

defmodule AstarteE2E.AmqpDataTrigger do
  use GenServer, restart: :temporary
  require Logger

  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias AstarteE2E.AmqpTriggers.Consumer
  alias AstarteE2E.Config
  alias AstarteE2E.Device

  def name, do: "AmqpDataTrigger"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    with {:ok, realm} <- Config.realm() do
      device_id = Astarte.Core.Device.random_device_id()
      interfaces = Keyword.fetch!(opts, :interfaces)
      device_opts = [realm: realm, device_id: device_id, interfaces: interfaces]

      datastream_interface =
        Enum.find(interfaces, &(&1[:type] == :datastream)) ||
          raise "no datastream interface present"

      properties_interface =
        Enum.find(interfaces, &(&1[:type] == :properties)) ||
          raise "no properties interface present"

      case Device.start_link(device_opts) do
        {:ok, device_pid} ->
          state = %{
            datastream_interface: datastream_interface,
            properties_interface: properties_interface,
            device_id: device_id,
            realm: realm,
            device_pid: device_pid,
            consumer_pid: nil,
            messages: nil
          }

          {:ok, state, {:continue, :install_triggers}}

        {:error, reason} ->
          Logger.error("Failed to start device: #{inspect(reason)}")
          {:stop, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to fetch realm: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:install_triggers, state) do
    %{
      datastream_interface: datastream_interface,
      properties_interface: properties_interface,
      device_id: device_id,
      realm: realm
    } = state

    case install_triggers(realm, device_id, properties_interface, datastream_interface) do
      :ok ->
        # "interface_name" => datastream_interface.interface_name,
        # "interface_major" => datastream_interface.version_major,
        properties = {properties_interface.interface_name, properties_interface.version_major}
        datastream = {datastream_interface.interface_name, datastream_interface.version_major}

        "Amqp Data Triggers installed successfully for interfaces #{inspect(properties)} and #{inspect(datastream)}."
        |> Logger.info()

        {:noreply, state, {:continue, :start_consumer}}

      {:error, reason} ->
        Logger.error("Failed to install amqp data triggers: #{inspect(reason)}")
        {:stop, {:failed_to_install_triggers, reason}, state}
    end
  end

  @impl true
  def handle_continue(:start_consumer, state) do
    me = self()
    message_handler = fn payload, meta -> GenServer.call(me, {:handle_message, payload, meta}) end

    consumer_opts = [
      realm_name: state.realm,
      routing_key: "e2e_data_triggers",
      message_handler: message_handler
    ]

    case Consumer.start_link(consumer_opts) do
      {:ok, consumer_pid} ->
        Logger.info("Amqp Data Trigger: consumer started")
        {:noreply, %{state | consumer_pid: consumer_pid}, {:continue, :publish_data}}

      {:error, reason} ->
        "Amqp Data Trigger: stopping due to consumer startup error: #{inspect(reason)}"
        |> Logger.error()

        {:stop, {:failed_to_start_consumer, reason}, state}
    end
  end

  def handle_continue(:publish_data, state) do
    %{
      datastream_interface: datastream_interface,
      properties_interface: properties_interface,
      device_pid: device_pid
    } = state

    case AstarteE2E.publish_data(device_pid, datastream_interface, properties_interface) do
      {:ok, %{datastreams: datastreams, property: property}} ->
        Logger.debug("AMQP Data Trigger: all messages sent")
        datastreams = Enum.map(datastreams, &{datastream_interface.name, &1})
        property = {properties_interface.name, property}
        messages = [property | datastreams]
        new_state = %{state | messages: messages}

        {:noreply, new_state}

      error ->
        Logger.debug("AMQP Data Trigger: message failure #{inspect(error)}")
        {:stop, error, state}
    end
  end

  @impl true
  def handle_continue(:stop, state) do
    Consumer.stop(state.consumer_pid)
    {:stop, :normal, state}
  end

  @impl true
  def handle_call({:handle_message, payload, _meta}, _from, state) do
    %SimpleEvent{event: {:incoming_data_event, event}} = SimpleEvent.decode(payload)
    %IncomingDataEvent{interface: interface, bson_value: bson_value} = event
    %{"v" => value} = Cyanide.decode!(bson_value)

    Logger.info("AMQP Data Trigger: handling #{inspect({interface, value})}")

    case pop_trigger(state.messages, interface, value) do
      {:ok, []} ->
        Logger.info("AMQP Data Trigger: all messages received")
        {:reply, :ok, %{state | messages: []}, {:continue, :stop}}

      {:ok, new_messages} ->
        {:reply, :ok, %{state | messages: new_messages}}

      {:error, :not_found} ->
        {:reply, {:error, :not_founnd}, state}
    end
  end

  def install_triggers(realm, device_id, properties_interface, datastream_interface) do
    triggers = generate_triggers(realm, device_id, properties_interface, datastream_interface)

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

  defp generate_triggers(realm, device_id, properties_interface, datastream_interface) do
    encoded_device_id = Astarte.Core.Device.encode_device_id(device_id)
    exchange = "astarte_events_#{realm}_#{Config.amqp_trigger_exchange_suffix!()}"
    routing_key = "e2e_data_triggers"

    [
      %{
        "name" => "amqptrigger-properties",
        "action" => %{
          "amqp_exchange" => exchange,
          "amqp_routing_key" => routing_key,
          "amqp_message_expiration_ms" => 100_000,
          "amqp_message_persistent" => false
        },
        "simple_triggers" => [
          %{
            "type" => "data_trigger",
            "on" => "incoming_data",
            "device_id" => encoded_device_id,
            "interface_name" => properties_interface.interface_name,
            "interface_major" => properties_interface.version_major,
            "match_path" => "/*",
            "value_match_operator" => "*"
          }
        ]
      },
      %{
        "name" => "amqptrigger-datastream",
        "action" => %{
          "amqp_exchange" => exchange,
          "amqp_routing_key" => routing_key,
          "amqp_message_expiration_ms" => 100_000,
          "amqp_message_persistent" => false
        },
        "simple_triggers" => [
          %{
            "type" => "data_trigger",
            "on" => "incoming_data",
            "device_id" => encoded_device_id,
            "interface_name" => datastream_interface.interface_name,
            "interface_major" => datastream_interface.version_major,
            "match_path" => "/*",
            "value_match_operator" => "*"
          }
        ]
      }
    ]
  end

  defp pop_trigger(messages, interface, value) do
    entry = {interface, value}

    case entry in messages do
      true ->
        Logger.debug("AMQP Data Trigger: received #{inspect(value)} for interface #{interface}")

        # There may be duplicate entries, only delete the first one
        first_trigger_value_index = messages |> Enum.find_index(&(&1 == entry))
        {:ok, List.delete_at(messages, first_trigger_value_index)}

      false ->
        "AMQP Data Trigger: unexpected message: #{inspect(value)} for interface #{interface}"
        |> Logger.debug()

        {:error, :not_found}
    end
  end
end
