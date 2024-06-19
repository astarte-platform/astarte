#
# This file is part of Astarte.
#
# Copyright 2021-2024 SECO Mind Srl
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
  import Bitwise

  @behaviour :gen_statem

  require Logger

  alias Astarte.Device
  alias AstarteDeviceFleetSimulator.Config
  alias AstarteDeviceFleetSimulator.CredentialsSecrets
  alias AstarteDeviceFleetSimulator.Scheduler
  alias Astarte.API.Pairing
  alias Astarte.API.Pairing.Agent

  @backoff_randomization_factor 0.25
  @max_backoff_exponent 9

  @impl true
  def callback_mode() do
    [:state_functions]
  end

  def start_link(args) do
    with {:ok, pid} <- :gen_statem.start_link(__MODULE__, args, []) do
      Logger.info("Started device process with pid #{inspect(pid)}.",
        tag: "device_process_started"
      )

      {:ok, pid}
    end
  end

  @impl true
  def init(args) do
    actions = [{:next_event, :internal, :start}]
    {:ok, :setup, args, actions}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :transient,
      shutdown: 500
    }
  end

  def setup(:internal, :start, data) do
    realm = Config.realm!()
    interface_provider = Config.standard_interface_provider!()
    path = Config.path!()
    auth_token = Config.jwt!()
    pairing_url = Config.pairing_url!()
    ignore_ssl_errors = Config.ignore_ssl_errors!()

    client =
      Pairing.client(pairing_url, realm,
        auth_token: auth_token,
        ignore_ssl_errors: ignore_ssl_errors
      )

    new_data =
      Map.merge(data, %{
        realm: realm,
        interface_provider: interface_provider,
        path: path,
        pairing_url: pairing_url,
        client: client
      })

    if data.credentials_secret == nil do
      actions = [{:next_event, :internal, :unregister}]
      {:keep_state, new_data, actions}
    else
      device_opts =
        data
        |> Map.take([:device_id, :credentials_secret])
        |> Keyword.new()
        |> Keyword.merge(Config.device_opts())

      {:ok, _} = Astarte.Device.start_link(device_opts)
      {:keep_state, new_data, [connecting_action()]}
    end
  end

  def setup(:internal, :unregister, data) do
    Logger.info("Unregistering credentials for device #{data.device_id}.",
      tag: "device_unregistering_started"
    )

    Agent.unregister_device(data.client, data.device_id)
    actions = [{:next_event, :internal, :register}]
    {:keep_state, data, actions}
  end

  def setup(:internal, :register, data) do
    Logger.info("Registering device #{data.device_id}.", tag: "device_registering_started")
    do_register(0, data)
  end

  def setup({:timeout, :register}, retry_times, data) do
    do_register(retry_times, data)
  end

  def setup(
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
      {:ok, _} = Registry.register(AstarteDeviceFleetSimulator.Registry, "device", [])

      new_data =
        Map.merge(data, %{
          interface: interface,
          publication_interval_ms: Config.publication_interval_ms!()
        })

      if Registry.count(AstarteDeviceFleetSimulator.Registry) == Config.device_count!() do
        GenServer.cast(Scheduler, :device_spawn_end)
      end

      if not data.skip_waiting do
        # wait for all other devices before running
        Logger.info("#{data.device_id} ready to start sending messages", tag: "device_ready")
        {:next_state, :waiting, new_data}
      else
        # do not wait for all devices
        Logger.info("#{data.device_id} started sending messages", tag: "device_sending_started")
        [path: path, value: value, qos: qos] = Config.message_opts()

        {:next_state, :running, new_data,
         [publish_action(Config.publication_interval_ms!(), path, value, qos)]}
      end
    end
  end

  def waiting(:cast, :begin_publishing, data) do
    Logger.info("#{data.device_id} started sending messages", tag: "device_sending_started")

    [path: path, value: value, qos: qos] = Config.message_opts()

    {:next_state, :running, data,
     [publish_action(Config.publication_interval_ms!(), path, value, qos)]}
  end

  def running({:timeout, :publish}, {path, value, qos}, data) do
    {:ok, device_pid} = fetch_device_pid(data.realm, data.device_id)
    Task.start(fn -> send_datastream(device_pid, data.interface, path, value, qos) end)
    {:keep_state_and_data, [publish_action(data.publication_interval_ms, path, value, qos)]}
  end

  defp do_register(retry_times, data) do
    with {:ok, %{body: %{"data" => %{"credentials_secret" => credentials_secret}}}} <-
           Agent.register_device(data.client, data.device_id),
         {:ok, _} <-
           Astarte.Device.start_link(
             Config.device_opts() ++
               [device_id: data.device_id, credentials_secret: credentials_secret]
           ) do
      if Config.avoid_registration!() do
        CredentialsSecrets.store(data.device_id, credentials_secret)
      end

      {:keep_state,
       %{
         client: data.client,
         device_id: data.device_id,
         credentials_secret: credentials_secret,
         realm: data.realm,
         interface_provider: data.interface_provider,
         path: data.path,
         skip_waiting: data.skip_waiting
       }, [connecting_action()]}
    else
      {:error, reason} ->
        Logger.error(inspect(reason))
        backoff_time = compute_backoff_time(retry_times)

        new_retry_times =
          if retry_times < @max_backoff_exponent, do: retry_times + 1, else: retry_times

        {:keep_state_and_data, [register_action(backoff_time, new_retry_times)]}
    end
  end

  defp fetch_device_pid(realm, device_id) do
    case Device.get_pid(realm, device_id) do
      nil -> {:error, :unregistered_device}
      pid -> {:ok, pid}
    end
  end

  defp send_datastream(device_pid, interface, path, value, qos) do
    Logger.debug("Sending #{value} on interface #{interface}, path #{path}, qos #{qos}")

    # blocking if qos != 0
    case Astarte.Device.send_datastream(device_pid, interface, path, value, qos: qos) do
      :ok -> :ok
      {:error, reason} -> Logger.error(inspect(reason))
    end
  end

  defp publish_action(publication_rate, path, value, qos) do
    {{:timeout, :publish}, publication_rate, {path, value, qos}}
  end

  defp connecting_action do
    {:next_event, :internal, :connect}
  end

  defp register_action(backoff_time, retry_times) do
    {{:timeout, :register}, backoff_time, retry_times}
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

  defp compute_backoff_time(current_attempt) do
    minimum_duration = (1 <<< current_attempt) * 1000
    minimum_duration + round(minimum_duration * @backoff_randomization_factor * :rand.uniform())
  end
end
