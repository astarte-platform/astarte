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
  alias AstarteE2E.Utils

  require Logger

  @doc "Starts the client process."
  @spec start_link(AstarteE2E.client_options()) :: GenSocketClient.on_start()
  def start_link(opts) do
    url = Keyword.fetch!(opts, :url)
    token = Keyword.fetch!(opts, :token)
    realm = Keyword.fetch!(opts, :realm)
    device_id = Keyword.fetch!(opts, :device_id)

    verify_option =
      if Keyword.get(opts, :ignore_ssl_errors, false) do
        :verify_none
      else
        :verify_peer
      end

    remote_device = {url, realm, token, device_id}

    with {:ok, pid} <-
           GenSocketClient.start_link(
             __MODULE__,
             WebSocketClient,
             remote_device,
             [transport_opts: [ssl_verify: verify_option]],
             name: :astarte_ws_client
           ) do
      Logger.info("[Client] Started process with pid #{inspect(pid)}.")

      :telemetry.execute(
        [:astarte_end_to_end, :astarte_platform, :status],
        %{health: 0}
      )

      {:ok, pid}
    end
  end

  def init({url, realm, token, device_id}) do
    topic = make_topic(realm, device_id)
    callback_state = %{device_id: device_id, topic: topic}
    query_params = [realm: realm, token: token]

    state = %{
      callback_state: callback_state,
      pending_requests: %{},
      pending_messages: %{}
    }

    {:connect, url, query_params, state}
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

  @spec fetch_pid() :: {:ok, pid()} | {:error, :unregistered_process}
  def fetch_pid do
    case Process.whereis(:astarte_ws_client) do
      nil -> {:error, :unregistered_process}
      pid -> {:ok, pid}
    end
  end

  def handle_connected(transport, state) do
    Logger.info("[Client] Connected.")
    join_topic(transport, state)
    {:ok, state}
  end

  def handle_disconnected(reason, state) do
    Logger.info("[Client] Disconnected with reason: #{inspect(reason)}.")

    :telemetry.execute(
      [:astarte_end_to_end, :astarte_platform, :status],
      %{health: 0}
    )

    {:ok, state}
  end

  def handle_joined(topic, _payload, transport, state) do
    Logger.info("[Client] Joined topic #{inspect(topic)}.")
    setup_watches(transport, state)
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
    Logger.info("[Client] Handling incoming_data message.")

    :telemetry.execute([:astarte_end_to_end, :messages, :received], %{})

    reception_timestamp = :erlang.monotonic_time(:millisecond)

    %{
      pending_messages: pending_messages,
      pending_requests: pending_requests
    } = state

    case Map.pop(pending_requests, {interface_name, path, value}) do
      {{timestamp, from}, new_pending_requests} ->
        dt_ms = reception_timestamp - timestamp
        new_state = Map.put(state, :pending_requests, new_pending_requests)

        Logger.info("[Client] Message verified. Round trip time = #{inspect(dt_ms)} ms.")

        :telemetry.execute(
          [:astarte_end_to_end, :messages, :round_trip_time],
          %{duration_seconds: dt_ms / 1_000}
        )

        :telemetry.execute(
          [:astarte_end_to_end, :astarte_platform, :status],
          %{health: 1}
        )

        GenSocketClient.reply(from, {:ok, {:round_trip_time_ms, dt_ms}})

        {:ok, new_state}

      _ ->
        new_pending_messages =
          Map.put(pending_messages, {interface_name, path, value}, reception_timestamp)

        new_state = Map.put(state, :pending_messages, new_pending_messages)
        {:ok, new_state}
    end
  end

  def handle_message(_topic, event, payload, _transport, state) do
    Logger.info(
      "[Client] Neglecting msg. Event: #{inspect(event)}, payload: #{inspect(payload)}."
    )

    {:ok, state}
  end

  def handle_reply(_topic, event, payload, _transport, state) do
    Logger.info(
      "[Client] Handling reply. Event: #{inspect(event)}, payload: #{inspect(payload)}."
    )

    {:ok, state}
  end

  def handle_join_error(topic, _payload, _transport, state) do
    Logger.warn("[Client] Stopping process.")
    {:stop, {:error, {:join_failed, topic}}, state}
  end

  def handle_info(:timeout, _transport, state) do
    Logger.error("[Client] Request timed out.")

    :telemetry.execute(
      [:astarte_end_to_end, :astarte_platform, :status],
      %{health: 0}
    )

    {:stop, :timeout, state}
  end

  def handle_info({:watch_error, reason}, _transport, _state) do
    {:error, reason}
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
      {reception_timestamp, new_pending_messages} =
        Map.pop(pending_messages, {interface_name, path, value})

      dt_ms = reception_timestamp - timestamp
      new_state = Map.put(state, :pending_messages, new_pending_messages)

      :telemetry.execute(
        [:astarte_end_to_end, :messages, :round_trip_time],
        %{duration_seconds: dt_ms / 1_000}
      )

      :telemetry.execute(
        [:astarte_end_to_end, :astarte_platform, :status],
        %{health: 1}
      )

      Logger.info("[Client] Round trip time = #{inspect(dt_ms)} ms.")

      {:reply, {:ok, {:round_trip_time_ms, dt_ms}}, new_state}
    else
      new_pending_requests =
        Map.put(pending_requests, {interface_name, path, value}, {timestamp, from})

      new_state = Map.put(state, :pending_requests, new_pending_requests)

      {:noreply, new_state}
    end
  end

  @spec verify_device_payload(String.t(), String.t(), any(), integer()) :: any()
  def verify_device_payload(interface_name, path, value, timestamp) do
    with {:ok, client_pid} <- fetch_pid() do
      GenSocketClient.call(
        client_pid,
        {:verify_payload, interface_name, path, value, timestamp}
      )
    end
  end

  defp join_topic(transport, state) do
    topic =
      state
      |> Map.fetch!(:callback_state)
      |> Map.fetch!(:topic)

    Logger.info("[Client] Asking to join topic #{inspect(topic)}.")

    case GenSocketClient.join(transport, topic) do
      {:error, reason} ->
        Logger.error("[Client] Cannot join topic #{inspect(topic)}. Reason: #{inspect(reason)}")
        {:error, :join_failed}

      {:ok, _ref} ->
        Logger.info("[Client] Joined join topic #{inspect(topic)}.")
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

    with :ok <- install_device_triggers(device_triggers, transport, state),
         :ok <- install_data_triggers(data_triggers, transport, state) do
      Logger.info("[Client] Triggers installed.")
      {:ok, state}
    else
      {:error, reason} ->
        Logger.warn("[Client] Failed to install triggers with reason: #{inspect(reason)}.")
        {:stop, reason, state}
    end
  end

  defp install_data_triggers(triggers, transport, state) do
    case install_device_triggers(triggers, transport, state) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp install_device_triggers(triggers, transport, %{callback_state: %{topic: topic}} = _state) do
    Enum.reduce_while(triggers, :ok, fn trigger, _acc ->
      case GenSocketClient.push(transport, topic, "watch", trigger) do
        {:error, reason} ->
          Logger.warn("[Client] Watch unsuccessful with reason: #{inspect(reason)}.")
          {:halt, {:error, reason}}

        {:ok, _ref} ->
          Logger.info("[Client] Successful watch request.")
          {:cont, :ok}
      end
    end)
  end

  defp make_topic(realm, device_id) do
    room_name = Utils.random_string()

    "rooms:#{realm}:#{device_id}_#{room_name}"
  end
end
