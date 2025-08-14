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
  use GenServer
  require Logger

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
            device_pid: device_pid
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
        Logger.info("Amqp Data Triggers installed successfully.")
        {:stop, :normal, state}

      {:error, reason} ->
        Logger.error("Failed to install amqp data triggers: #{inspect(reason)}")
        {:stop, {:failed_to_install_triggers, reason}, state}
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

    [
      %{
        "name" => "test_trigger_1",
        "action" => %{
          "amqp_exchange" => "astarte_events_#{realm}_test_exchange",
          "amqp_routing_key" => "my_routing_key",
          "amqp_message_expiration_ms" => 100_000,
          "amqp_message_persistent" => false
        },
        "simple_triggers" => [
          %{
            "type" => "data_trigger",
            "on" => "incoming_data",
            "interface_name" => properties_interface.interface_name,
            "interface_major" => properties_interface.version_major,
            "match_path" => "/*",
            "value_match_operator" => "*"
          }
        ]
      },
      %{
        "name" => "test_trigger_2",
        "action" => %{
          "amqp_exchange" => "astarte_events_#{realm}_test_exchange",
          "amqp_routing_key" => "my_routing_key",
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
end
