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
#

defmodule AstarteE2E.DataTrigger do
  use GenServer, restart: :temporary

  alias Astarte.Core.Device, as: CoreDevice
  alias AstarteE2E.Config
  alias AstarteE2E.Device
  alias AstarteE2E.Utils

  require Logger

  @datastream_trigger "valuetrigger-datastream"
  @properties_trigger "valuetrigger-properties"

  def name, do: "data trigger roundtrip"

  def start_link(init_arg) do
    device_id = CoreDevice.random_device_id()
    realm = Config.realm!()
    init_arg = init_arg |> Keyword.merge(device_id: device_id, realm: realm)
    GenServer.start_link(__MODULE__, init_arg, name: via_tuple(realm, device_id))
  end

  def handle_trigger(realm, device_id, trigger, event) do
    via_tuple(realm, device_id)
    |> GenServer.call({:handle_trigger, trigger, event})
  end

  @impl GenServer
  def init(opts) do
    realm = Keyword.fetch!(opts, :realm)
    device_id = Keyword.fetch!(opts, :device_id) 
    encoded_id = Astarte.Core.Device.encode_device_id(device_id)

    interfaces = Keyword.fetch!(opts, :interfaces)

    datastream_interface =
      Enum.find(interfaces, &(&1[:type] == :datastream)) ||
        raise "no datastream interface present"

    properties_interface =
      Enum.find(interfaces, &(&1[:type] == :properties)) ||
        raise "no properties interface present"

    opts = [
      realm: realm,
      device_id: device_id,
      interfaces: interfaces,
      datastream_interface: datastream_interface,
      properties_interface: properties_interface
    ]

    with {:ok, device_supervisor_pid} <- Device.start_link(opts),
         device_pid = Device.astarte_device_pid(device_supervisor_pid),
         :ok <- Astarte.Device.wait_for_connection(device_pid),
         :ok <- install_data_trigger(opts) do
      state = %{
        realm: realm,
        device_id: encoded_id,
        device_pid: device_pid,
        messages: [],
        datastream_interface: datastream_interface,
        properties_interface: properties_interface
      }

      {:ok, state, {:continue, :publish_data}}
    end
  end

  @impl true
  def handle_continue(:publish_data, state) do
    %{
      device_pid: device_pid,
      datastream_interface: datastream_interface,
      properties_interface: properties_interface
    } = state

    datastream_name = datastream_interface.name
    properties_name = properties_interface.name

    datastreams = Enum.map(1..5, fn _ -> AstarteE2E.Utils.random_string() end)
    property = AstarteE2E.Utils.random_string()

    datastream_path =
      datastream_interface.mappings |> hd() |> Map.fetch!(:endpoint) |> path_from_endpoint()

    properties_path =
      properties_interface.mappings |> hd() |> Map.fetch!(:endpoint) |> path_from_endpoint()

    with :ok <- publish_datastreams(device_pid, datastream_name, datastream_path, datastreams),
         :ok <-
           Astarte.Device.set_property(device_pid, properties_name, properties_path, property) do
      Logger.debug("Data Trigger: all messages sent")
      datastreams = Enum.map(datastreams, &{@datastream_trigger, &1})
      property = {@properties_trigger, property}
      messages = [property | datastreams]
      new_state = %{state | messages: messages}

      {:noreply, new_state}
    else
      error ->
        Logger.debug("Data Trigger: message failure #{inspect(error)}")
        {:stop, error, state}
    end
  end

  defp publish_datastreams(device_pid, datastream_interface, path, datastreams) do
    Enum.reduce_while(datastreams, :ok, fn datastream, :ok ->
      case Astarte.Device.send_datastream(device_pid, datastream_interface, path, datastream) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @impl GenServer
  def handle_call({:handle_trigger, trigger, event}, _from, state) do
    %{"value" => value} = event

    case pop_trigger(state.messages, trigger, value) do
      {:ok, []} -> {:stop, :normal, :ok, %{state | messages: []}}
      {:ok, new_messages} -> {:reply, :ok, %{state | messages: new_messages}}
      {:error, :not_found} -> {:reply, {:error, :not_founnd}, state}
    end
  end

  def install_data_trigger(opts) do
    device_id = Keyword.fetch!(opts, :device_id)
    encoded_id = CoreDevice.encode_device_id(device_id)
    base_url = Config.realm_management_url!()
    realm = Config.realm!()
    astarte_jwt = Config.jwt!()

    datastream_interface = Keyword.fetch!(opts, :datastream_interface)
    properties_interface = Keyword.fetch!(opts, :properties_interface)

    url = Path.join([base_url, "v1", realm, "triggers"])

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    trigger_url = Config.base_url!() |> Path.join("triggers/data")

    triggers = [
      %{
        name: @datastream_trigger,
        simple_triggers: [
          %{
            device_id: encoded_id,
            type: "data_trigger",
            on: "incoming_data",
            interface_name: datastream_interface.interface_name,
            interface_major: datastream_interface.version_major,
            match_path: "/*",
            value_match_operator: "*"
          }
        ],
        action: %{
          http_post_url: trigger_url
        }
      },
      %{
        name: @properties_trigger,
        simple_triggers: [
          %{
            device_id: encoded_id,
            type: "data_trigger",
            on: "incoming_data",
            interface_name: properties_interface.interface_name,
            interface_major: properties_interface.version_major,
            match_path: "/*",
            value_match_operator: "*"
          }
        ],
        action: %{
          http_post_url: trigger_url
        }
      }
    ]

    Enum.reduce_while(triggers, :ok, fn trigger, :ok ->
      body = Jason.encode!(%{"data" => trigger})

      case HTTPoison.post(url, body, headers) do
        {:ok, %HTTPoison.Response{status_code: 201}} ->
          {:cont, :ok}

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          {:halt, {:error, %{status: code, body: body}}}

        {:error, %HTTPoison.Error{} = error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  def via_tuple(realm, device_id) do
    {:via, Registry, {Registry.AstarteE2E, {:http_data_trigger, realm, device_id}}}
  end

  defp pop_trigger(messages, trigger, value) do
    trigger_value = {trigger, value}

    case trigger_value in messages do
      true ->
        Logger.debug("Data Trigger: received #{inspect(value)} for trigger #{trigger}")

        # There may be duplicate entries, only delete the first one
        first_trigger_value_index = messages |> Enum.find_index(&(&1 == trigger_value))
        {:ok, List.delete_at(messages, first_trigger_value_index)}

      false ->
        Logger.debug("Data Trigger: unexpected message: #{inspect(value)} for trigger #{trigger}")
        {:error, :not_found}
    end
  end

  defp path_from_endpoint(endpoint) do
    endpoint
    |> String.split("/")
    |> Enum.map(fn token ->
      if Astarte.Core.Mapping.is_placeholder?(token) do
        Utils.random_string()
      else
        token
      end
    end)
    |> Enum.join("/")
  end
end
