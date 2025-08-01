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

defmodule AstarteE2E.DeviceTrigger do
  use GenServer, restart: :temporary

  require Logger

  alias AstarteE2E.Config
  alias AstarteE2E.Device
  alias Astarte.Core.Device, as: CoreDevice

  def name, do: "device trigger roundtrip"

  def start_link(init_arg) do
    device_id = CoreDevice.random_device_id()
    realm = Config.realm!()
    init_arg = init_arg |> Keyword.merge(device_id: device_id, realm: realm)
    GenServer.start_link(__MODULE__, init_arg, name: via_tuple(realm, device_id))
  end

  @impl GenServer
  def init(opts) do
    realm = Keyword.fetch!(opts, :realm)
    device_id = Keyword.fetch!(opts, :device_id)
    encoded_id = Astarte.Core.Device.encode_device_id(device_id)
    opts = [realm: realm, device_id: device_id]

    with :ok <- install_device_triggers!(realm, encoded_id),
         {:ok, _} <- Device.start_link(opts) do
      {:ok, %{device_id: encoded_id}}
    end
  end

  def handle_trigger(realm, device_id, trigger, event) do
    via_tuple(realm, device_id)
    |> GenServer.call({:handle_trigger, trigger, event})
  end

  @impl GenServer
  def handle_call(
        {:handle_trigger, _trigger, %{"type" => "device_connected"} = _event},
        _from,
        state
      ) do
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_call(
        {:handle_trigger, _trigger, event},
        _from,
        state
      ) do
    "Device Trigger: received unexpected trigger: #{inspect(event)}"
    |> Logger.info(device_id: state.device_id)

    {:reply, {:error, :unexpected_trigger}, state}
  end

  def install_device_triggers!(realm, device_id) do
    triggers = generate_triggers(device_id)

    realm_management_url = Config.realm_management_url!()
    astarte_jwt = Config.jwt!()

    url = Path.join([realm_management_url, "v1", realm, "triggers"])

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    triggers
    |> Enum.map(&%{"data" => &1})
    |> Enum.map(&Jason.encode(&1))
    |> Enum.reduce_while(:ok, fn encoded_body, acc ->
      {:ok, body} = encoded_body
      response = HTTPoison.post!(url, body, headers)

      case {acc, response} do
        {:ok, %HTTPoison.Response{status_code: 201}} ->
          {:cont, :ok}

        _ ->
          {:halt, response}
      end
    end)
  end

  defp generate_triggers(device_id) do
    trigger_url = Config.base_url!() |> Path.join("triggers/device")

    [
      %{
        name: "device_connection",
        action: %{
          http_post_url: trigger_url
        },
        simple_triggers: [
          %{
            type: :device_trigger,
            device_id: device_id,
            on: :device_connected
          }
        ]
      }
    ]
  end

  def via_tuple(realm, device_id) do
    {:via, Registry, {Registry.AstarteE2E, {:http_device_trigger, realm, device_id}}}
  end
end
