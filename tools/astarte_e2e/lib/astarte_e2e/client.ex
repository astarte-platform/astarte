#
# This file is part of Astarte.
#
# Cospyright 2020 Ispirata Srl
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

defmodule AstarteE2E.Client do
  alias Phoenix.Channels.GenSocketClient
  alias Phoenix.Channels.GenSocketClient.Transport.WebSocketClient
  alias AstarteE2E.{Utils, Config, ServiceNotifier}

  require Logger

  @connection_backoff_ms 10_000
  @connection_attempts 10

  # API

  @doc "Starts the client process."
  @spec start_link(Config.client_options()) :: GenServer.on_start()
  def start_link(opts) do
    url = Keyword.fetch!(opts, :url)
    jwt = Keyword.fetch!(opts, :jwt)
    realm = Keyword.fetch!(opts, :realm)
    device_id = Keyword.fetch!(opts, :device_id)
    check_repetitions = Keyword.fetch!(opts, :check_repetitions)

    remote_device = [
      url: url,
      realm: realm,
      jwt: jwt,
      device_id: device_id,
      check_repetitions: check_repetitions
    ]

    with {:ok, pid} <-
           GenSocketClient.start_link(
             __MODULE__,
             WebSocketClient,
             remote_device,
             socket_options(opts),
             name: via_tuple(realm, device_id)
           ) do
      :telemetry.execute(
        [:astarte_end_to_end, :astarte_platform],
        %{status: 0}
      )

      Logger.info("Started process with pid #{inspect(pid)}.", tag: "client_started")

      {:ok, pid}
    end
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

  @spec verify_device_payload(String.t(), String.t(), String.t(), String.t(), any(), integer()) ::
          :ok
          | {:error, :not_connected | :timeout}
  def verify_device_payload(realm, device_id, interface_name, path, value, timestamp) do
    via_tuple(realm, device_id)
    |> GenSocketClient.call(
      {:verify_payload, interface_name, path, value, timestamp},
      :infinity
    )
  end

  def wait_for_connection(realm, device_id) do
    via_tuple(realm, device_id)
    |> GenSocketClient.call(:wait_for_connection, :infinity)
  end

  defp join_topic(transport, state) do
    topic =
      state
      |> Map.fetch!(:callback_state)
      |> Map.fetch!(:topic)

    Logger.info("Asking to join topic #{inspect(topic)}.", tag: "join_request")

    case GenSocketClient.join(transport, topic) do
      {:error, reason} ->
        Logger.error("Cannot join topic #{inspect(topic)}. Reason: #{inspect(reason)}",
          tag: "join_failed"
        )

        {:error, :join_failed}

      {:ok, _ref} ->
        Logger.info("Joined topic #{inspect(topic)}.", tag: "join_success")

        {:ok, state}
    end
  end

  defp setup_watches(transport, state) do
    callback_state =
      state
      |> Map.fetch!(:callback_state)

    device_id = Map.fetch!(callback_state, :device_id)

    device_triggers = [
      %{
        name: "connectiontrigger-#{device_id}",
        device_id: device_id,
        simple_trigger: %{
          type: "device_trigger",
          on: "device_connected",
          device_id: device_id
        }
      },
      %{
        name: "disconnectiontrigger-#{device_id}",
        device_id: device_id,
        simple_trigger: %{
          type: "device_trigger",
          on: "device_disconnected",
          device_id: device_id
        }
      }
    ]

    data_triggers = [
      %{
        name: "valuetrigger-#{device_id}",
        device_id: device_id,
        simple_trigger: %{
          type: "data_trigger",
          on: "incoming_data",
          interface_name: "*",
          interface_major: 1,
          match_path: "/*",
          value_match_operator: "*"
        }
      }
    ]

    with :ok <- install_triggers(device_triggers, transport, state),
         :ok <- install_triggers(data_triggers, transport, state) do
      Logger.info("Triggers installed.", tag: "triggers_installed")
      :ok
    else
      {:error, reason} ->
        Logger.warning("Failed to install triggers with reason: #{inspect(reason)}.",
          tag: "install_triggers_failed"
        )

        {:error, reason}
    end
  end

  defp install_triggers(triggers, transport, %{callback_state: %{topic: topic}} = _state) do
    Enum.reduce_while(triggers, :ok, fn trigger, _acc ->
      case GenSocketClient.push(transport, topic, "watch", trigger) do
        {:error, reason} ->
          Logger.warning("Watch failed with reason: #{inspect(reason)}.",
            tag: "watch_failed"
          )

          {:halt, {:error, reason}}

        {:ok, _ref} ->
          Logger.info("Successful watch request.",
            tag: "watch_success"
          )

          {:cont, :ok}
      end
    end)
  end

  defp make_topic(realm, device_id) do
    room_name = Utils.random_string()

    "rooms:#{realm}:#{device_id}_#{room_name}"
  end

  defp socket_options(opts) do
    if Keyword.get(opts, :ignore_ssl_errors, false) do
      [transport_opts: [ssl_verify: :verify_none]]
    else
      [
        transport_opts: [
          ssl_verify: :verify_peer,
          socket_opts: [
            cacertfile: :certifi.cacertfile(),
            customize_hostname_check: [
              match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
            ],
            depth: 10
          ]
        ]
      ]
    end
  end

  defp via_tuple(realm, device_id) do
    {:via, Registry, {Registry.AstarteE2E, {:client, realm, device_id}}}
  end

  # Callbacks

  def init(opts) do
    url = Keyword.fetch!(opts, :url)
    realm = Keyword.fetch!(opts, :realm)
    jwt = Keyword.fetch!(opts, :jwt)
    device_id = Keyword.fetch!(opts, :device_id)
    check_repetitions = Keyword.fetch!(opts, :check_repetitions)

    topic = make_topic(realm, device_id)

    callback_state = %{
      device_id: device_id,
      topic: topic
    }

    query_params = [realm: realm, token: jwt]

    state = %{
      callback_state: callback_state,
      pending_requests: %{},
      pending_messages: %{},
      connection_attempts: @connection_attempts,
      check_repetitions: check_repetitions,
      waiting_for_connection: %{},
      timeouts_to_crash: Config.client_max_timeouts!(),
      connected: false
    }

    {:connect, url, query_params, state}
  end

  def handle_connected(transport, state) do
    Logger.info("Connected.", tag: "client_connected")

    waiting_for_connection = state.waiting_for_connection

    new_waiting =
      if Map.has_key?(waiting_for_connection, self()) do
        {tref, new_waiting} = Map.pop!(waiting_for_connection, self())
        :ok = Process.cancel_timer(tref, async: false, info: false)
        new_waiting
      else
        waiting_for_connection
      end

    new_state = %{
      state
      | waiting_for_connection: new_waiting,
        connection_attempts: @connection_attempts,
        connected: true
    }

    {:ok, updated_state} = join_topic(transport, new_state)
    {:ok, updated_state}
  end

  def handle_disconnected(reason, state) do
    :telemetry.execute(
      [:astarte_end_to_end, :astarte_platform],
      %{status: 0}
    )

    ServiceNotifier.notify_service_down("Client disconnected")

    Logger.info("Disconnected with reason: #{inspect(reason)}.",
      tag: "client_disconnected"
    )

    Process.send_after(self(), :try_connect, @connection_backoff_ms)

    {:ok, %{state | connected: false}}
  end

  def handle_joined(topic, _payload, transport, state) do
    Logger.info("Joined topic #{inspect(topic)}.", tag: "topic_joined")

    case setup_watches(transport, state) do
      :ok -> {:ok, state}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  def handle_channel_closed(topic, _payload, _transport, state) do
    Logger.warning("Channel closed for #{inspect(topic)}.",
      tag: "channel_closed"
    )

    {:ok, state}
  end

  def handle_message(
        _topic,
        _event,
        %{
          "event" => %{
            "interface" => interface_name,
            "path" => path,
            "type" => "incoming_data",
            "value" => value
          }
        } = _payload,
        _transport,
        state
      ) do
    Logger.debug("Handling incoming data message.", tag: "handle_incoming_message")

    :telemetry.execute([:astarte_end_to_end, :messages, :received], %{})

    reception_timestamp = :erlang.monotonic_time(:millisecond)

    %{
      pending_messages: pending_messages,
      pending_requests: pending_requests
    } = state

    if Map.has_key?(pending_requests, {interface_name, path, value}) do
      {{timestamp, from, tref}, new_pending_requests} =
        Map.pop(pending_requests, {interface_name, path, value})

      :ok = Process.cancel_timer(tref, async: false, info: false)

      Logger.debug("Timeout timer canceled successfully in handle_message.",
        tag: "cancel_timer_success"
      )

      dt_ms = reception_timestamp - timestamp
      new_state = Map.put(state, :pending_requests, new_pending_requests)

      Logger.debug("Message verified. Round trip time = #{inspect(dt_ms)} ms.")

      :telemetry.execute(
        [:astarte_end_to_end, :messages, :round_trip_time],
        %{duration_seconds: dt_ms / 1_000}
      )

      :telemetry.execute(
        [:astarte_end_to_end, :astarte_platform],
        %{status: 1}
      )

      ServiceNotifier.notify_service_up()

      GenSocketClient.reply(from, :ok)
      {:ok, new_state}
    else
      timeout_ms =
        Config.client_timeout_s!()
        |> Utils.to_ms()

      key = {interface_name, path, value}
      tref = Process.send_after(self(), {:message_timeout, key}, timeout_ms)

      new_pending_messages = Map.put(pending_messages, key, {reception_timestamp, tref})

      new_state = Map.put(state, :pending_messages, new_pending_messages)
      {:ok, new_state}
    end
  end

  def handle_message(_topic, event, payload, _transport, state) do
    Logger.debug("Ignoring msg. Event: #{inspect(event)}, payload: #{inspect(payload)}.")

    {:ok, state}
  end

  def handle_reply(_topic, event, payload, _transport, state) do
    Logger.debug("Handling reply. Event: #{inspect(event)}, payload: #{inspect(payload)}.")

    {:ok, state}
  end

  def handle_join_error(topic, _payload, _transport, state) do
    Logger.error(
      "Join topic #{inspect(topic)} failed. Please, check the realm and the claims you used to generate the token.",
      tag: "join_error"
    )

    System.stop(1)
    {:stop, :join_error, state}
  end

  def handle_info(
        {:message_timeout, key},
        _transport,
        %{pending_messages: pending_messages} = state
      ) do
    :telemetry.execute(
      [:astarte_end_to_end, :astarte_platform],
      %{status: 0}
    )

    ServiceNotifier.notify_service_down("Message timeout")

    Logger.warning("Incoming message timeout. Key = #{inspect(key)}",
      tag: "message_timeout"
    )

    {{_ts, _tref}, new_pending_messages} = Map.pop(pending_messages, key)
    {:ok, %{state | pending_messages: new_pending_messages}}
  end

  def handle_info(
        {:request_timeout, key},
        _transport,
        %{pending_requests: pending_requests, timeouts_to_crash: 0} = state
      ) do
    :telemetry.execute(
      [:astarte_end_to_end, :astarte_platform],
      %{status: 0}
    )

    ServiceNotifier.notify_service_down("Maximum number of request timeout reached")

    Logger.warning(
      "Maximum number of requests timeout reached. The websocket client is going to crash.",
      tag: "maximum_timeout_number_reached"
    )

    {{_ts, from, _tref}, _new_pending_requests} = Map.pop(pending_requests, key)

    :ok = GenSocketClient.reply(from, {:error, :timeout})
    {:stop, :maximum_timeout_number_reached, state}
  end

  def handle_info(
        {:request_timeout, key},
        _transport,
        %{pending_requests: pending_requests} = state
      ) do
    :telemetry.execute(
      [:astarte_end_to_end, :astarte_platform],
      %{status: 0}
    )

    ServiceNotifier.notify_service_down("Request timeout")

    Logger.warning("Request timed out. Key = #{inspect(key)}", tag: "request_timeout")

    {{_ts, from, _tref}, new_pending_requests} = Map.pop(pending_requests, key)
    remaining_timeouts_to_crash = state.timeouts_to_crash - 1

    :ok = GenSocketClient.reply(from, {:error, :timeout})

    {:ok,
     %{
       state
       | pending_requests: new_pending_requests,
         timeouts_to_crash: remaining_timeouts_to_crash
     }}
  end

  def handle_info(:try_connect, _transport, %{check_repetitions: :infinity} = state) do
    {:connect, state}
  end

  def handle_info(:try_connect, _transport, state) do
    if state.connection_attempts > 0 do
      updated_attempts = state.connection_attempts - 1
      updated_state = %{state | connection_attempts: updated_attempts}
      {:connect, updated_state}
    else
      Logger.warning(
        "Cannot establish a connection after #{inspect(@connection_attempts)} attempts. Closing application.",
        tag: "connection_failed"
      )

      System.stop(1)
      {:stop, :connection_failed, state}
    end
  end

  def handle_info({:wait_for_connection_expired, from}, _transport, state) do
    {_tref, new_waiting} = Map.pop!(state.waiting_for_connection, from)
    :ok = GenSocketClient.reply(from, {:error, :not_connected})

    {:ok, %{state | waiting_for_connection: new_waiting}}
  end

  def handle_call(:wait_for_connection, _from, _transport, %{connected: true} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:wait_for_connection, from, _transport, %{connected: false} = state) do
    tref =
      Process.send_after(self(), {:wait_for_connection_expired, from}, @connection_backoff_ms)

    waiting_for_connection =
      state.waiting_for_connection
      |> Map.put(from, tref)

    updated_state = %{state | waiting_for_connection: waiting_for_connection}

    {:noreply, updated_state, @connection_backoff_ms}
  end

  def handle_call(
        {:verify_payload, _interface_name, _path, _value, _timestamp},
        _from,
        _transport,
        %{connected: false} = state
      ) do
    :telemetry.execute([:astarte_end_to_end, :messages, :failed], %{})

    Logger.warning("Cannot verify the payload: the client is not connected.",
      tag: "verify_not_possible"
    )

    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(
        {:verify_payload, interface_name, path, value, timestamp},
        from,
        _transport,
        state
      ) do
    %{
      pending_messages: pending_messages,
      pending_requests: pending_requests
    } = state

    if Map.has_key?(pending_messages, {interface_name, path, value}) do
      {{reception_timestamp, tref}, new_pending_messages} =
        Map.pop(pending_messages, {interface_name, path, value})

      :ok = Process.cancel_timer(tref, async: false, info: false)

      Logger.debug("Timeout timer canceled successfully in handle_call.",
        tag: "cancel_timer_success"
      )

      dt_ms = reception_timestamp - timestamp

      new_state = %{
        state
        | pending_messages: new_pending_messages,
          timeouts_to_crash: Config.client_max_timeouts!()
      }

      :telemetry.execute(
        [:astarte_end_to_end, :messages, :round_trip_time],
        %{duration_seconds: dt_ms / 1_000}
      )

      :telemetry.execute(
        [:astarte_end_to_end, :astarte_platform],
        %{status: 1}
      )

      ServiceNotifier.notify_service_up()

      Logger.debug("Round trip time = #{inspect(dt_ms)} ms.")

      {:reply, :ok, new_state}
    else
      timeout_ms =
        Config.client_timeout_s!()
        |> Utils.to_ms()

      key = {interface_name, path, value}
      tref = Process.send_after(self(), {:request_timeout, key}, timeout_ms)

      new_pending_requests = Map.put(pending_requests, key, {timestamp, from, tref})
      new_state = Map.put(state, :pending_requests, new_pending_requests)

      {:noreply, new_state}
    end
  end
end
