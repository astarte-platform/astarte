#
# This file is part of Astarte.
#
# Copyright 2021 Ispirata Srl
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

defmodule AstarteDeviceFleetSimulator.Device do
  @behaviour :gen_statem

  require Logger

  alias Astarte.API.Pairing
  alias Astarte.Device
  alias AstarteDeviceFleetSimulator.Config

  @impl true
  def callback_mode() do
    [:state_functions]
  end

  # API

  def start_link(args) do
    with {:ok, pid} <- :gen_statem.start_link(__MODULE__, args, []) do
      Logger.info("Started device process with pid #{inspect(pid)}.", tag: "process_started")

      {:ok, pid}
    end
  end

  @impl true
  def init(_args) do
    # timeout?
    # check if it fits
    # Process.flag(:trap_exit, true)
    actions = [{:next_event, :internal, :register}]
    {:ok, :registering, %{}, actions}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def registering(:internal, :register, _data) do
    realm = Config.realm!()
    interface_provider = Config.standard_interface_provider!()
    path = Config.path!()
    auth_token = Config.jwt!()
    pairing_url = Config.pairing_url!()
    ignore_ssl_errors = Config.ignore_ssl_errors!()

    device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    with {:ok, %{body: %{"data" => %{"credentials_secret" => credentials_secret}}}} <-
           Pairing.client(pairing_url, realm,
             auth_token: auth_token,
             ignore_ssl_errors: ignore_ssl_errors
           )
           |> Pairing.Agent.register_device(device_id),
         {:ok, _} <-
           Astarte.Device.start_link(
             Config.device_opts() ++
               [device_id: device_id, credentials_secret: credentials_secret]
           ) do
      {:next_state, :connecting,
       %{
         device_id: device_id,
         credentials_secret: credentials_secret,
         realm: realm,
         interface_provider: interface_provider,
         path: path
       }, connecting_action()}
    else
      {:error, reason} ->
        Logger.error(reason)
        # timeout?
        {:keep_state_and_data}
    end
  end

  def connecting(
        :internal,
        :connect,
        %{
          device_id: device_id,
          realm: realm
        } = data
      ) do
    with {:ok, device_pid} <- fetch_device_pid(realm, device_id),
         {:ok, [interface]} <- fetch_interface_names(),
         # blocking
         :ok <-
           Device.wait_for_connection(device_pid) do
      new_data =
        Map.merge(data, %{
          interface: interface,
          publication_interval_ms: Config.publication_interval_ms!()
        })

      [path: path, value: value, qos: qos] = Config.message_opts()

      {:next_state, :running, new_data,
       publish_action(Config.publication_interval_ms!(), path, value, qos)}
    end
  end

  def running({:timeout, :publish}, {path, value, qos}, data) do
    {:ok, device_pid} = fetch_device_pid(data.realm, data.device_id)
    Task.start(fn -> send_datastream(device_pid, data.interface, path, value, qos) end)
    {:keep_state_and_data, publish_action(data.publication_interval_ms, path, value, qos)}
  end

  defp fetch_device_pid(realm, device_id) do
    case Device.get_pid(realm, device_id) do
      nil -> {:error, :unregistered_device}
      pid -> {:ok, pid}
    end
  end

  defp send_datastream(device_pid, interface, path, value, qos) do
    Logger.debug("Sending #{value} on interface #{interface}, path #{path}, qos #{qos}")

    case Astarte.Device.send_datastream(device_pid, interface, path, value, qos: qos) do
      :ok -> :ok
      {:error, reason} -> Logger.error(inspect(reason))
    end
  end

  defp publish_action(publication_rate, path, value, qos) do
    [
      {{:timeout, :publish}, publication_rate, {path, value, qos}}
    ]
  end

  defp connecting_action() do
    [{:next_event, :internal, :connect}]
  end

  defp fetch_interface_names do
    with {:ok, interface_path} <- Config.standard_interface_provider(),
         {:ok, raw_interfaces_list} <- File.ls(interface_path) do
      interface_names =
        Enum.reduce(raw_interfaces_list, [], fn raw_interface, acc ->
          interface_name =
            raw_interface
            |> String.trim(".json")

          [interface_name | acc]
        end)

      {:ok, interface_names}
    else
      error ->
        Logger.error("Interfaces names cannot be retrieved. Reason: #{inspect(error)}")
    end
  end
end
