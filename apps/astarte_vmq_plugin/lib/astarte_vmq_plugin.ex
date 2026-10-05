#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin do
  @moduledoc """
  Documentation for Astarte.VMQ.Plugin.
  """

  alias Astarte.Core.Device
  alias Astarte.VMQ.Plugin.Config
  alias Astarte.VMQ.Plugin.Connection.Synchronizer
  alias Astarte.VMQ.Plugin.Connection.Synchronizer.Supervisor, as: SynchronizerSupervisor
  alias Astarte.VMQ.Plugin.Queries
  alias Mississippi.Producer.EventsProducer

  @max_rand trunc(:math.pow(2, 32) - 1)
  @vernemq_api Application.compile_env(
                 :astarte_vmq_plugin,
                 :vernemq_api,
                 Astarte.VMQ.Plugin.VerneMQ.API
               )

  def auth_on_register(_peer, _subscriber_id, :undefined, _password, _cleansession) do
    # If it doesn't have a username we let someone else decide
    :next
  end

  def auth_on_register(_peer, {mountpoint, _client_id}, username, _password, _cleansession) do
    if String.contains?(username, "/") do
      authorize_registration(mountpoint, username)
    else
      # Not a device, let someone else decide
      :next
    end
  end

  def auth_on_publish(
        _username,
        {_mountpoint, client_id},
        _qos,
        topic_tokens,
        _payload,
        _isretain
      ) do
    cond do
      # Not a device, let someone else decide
      !String.contains?(client_id, "/") ->
        :next

      # Device auth
      String.split(client_id, "/") == Enum.take(topic_tokens, 2) ->
        :ok

      true ->
        {:error, :unauthorized}
    end
  end

  def auth_on_subscribe(_username, {_mountpoint, client_id}, topics) do
    if String.contains?(client_id, "/") do
      client_id_tokens = String.split(client_id, "/")

      authorized_topics =
        Enum.filter(topics, fn {topic_tokens, _qos} ->
          client_id_tokens == Enum.take(topic_tokens, 2)
        end)

      case authorized_topics do
        [] -> {:error, :unauthorized}
        authorized_topics -> {:ok, authorized_topics}
      end
    else
      # Not a device, let someone else decide
      :next
    end
  end

  def disconnect_client(client_id, discard_state) do
    opts =
      if discard_state do
        [:do_cleanup]
      else
        []
      end

    mountpoint = ~c""
    subscriber_id = {mountpoint, client_id}

    case @vernemq_api.disconnect_by_subscriber_id(subscriber_id, opts) do
      :ok ->
        :ok

      :not_found ->
        {:error, :not_found}
    end
  end

  def on_client_gone({_mountpoint, client_id}) do
    timestamp = now_us_x10_timestamp()

    get_connection_synchronizer_process!(client_id)
    |> Synchronizer.handle_disconnection(timestamp)
  end

  def on_client_offline({_mountpoint, client_id}) do
    timestamp = now_us_x10_timestamp()

    get_connection_synchronizer_process!(client_id)
    |> Synchronizer.handle_disconnection(timestamp)
  end

  def on_register({ip_addr, _port}, {_mountpoint, client_id}, _username) do
    case String.split(client_id, "/") do
      [realm, device_id] ->
        # Start the heartbeat
        setup_heartbeat_timer(realm, device_id, self())

        timestamp = now_us_x10_timestamp()

        ip_string =
          ip_addr
          |> :inet.ntoa()
          |> to_string()

        get_connection_synchronizer_process!(client_id)
        |> Synchronizer.handle_connection(timestamp, x_astarte_remote_ip: ip_string)

      # Not a device, ignoring it
      _ ->
        :ok
    end
  end

  def on_publish(_username, {_mountpoint, client_id}, _qos, topic_tokens, payload, _isretain) do
    case String.split(client_id, "/") do
      [realm, device_id] ->
        timestamp = now_us_x10_timestamp()

        case topic_tokens do
          [^realm, ^device_id] ->
            publish_introspection(realm, device_id, payload, timestamp)

          [^realm, ^device_id, "control" | control_path_tokens] ->
            control_path = "/" <> Enum.join(control_path_tokens, "/")
            publish_control_message(realm, device_id, control_path, payload, timestamp)

          [^realm, ^device_id, "capabilities"] ->
            publish_capabilities(realm, device_id, payload, timestamp)

          [^realm, ^device_id, interface | path_tokens] ->
            path = "/" <> Enum.join(path_tokens, "/")
            publish_data(realm, device_id, interface, path, payload, timestamp)
        end

      # Not a device, ignoring it
      _ ->
        :ok
    end
  end

  def handle_heartbeat(realm, device_id, session_pid) do
    if Process.alive?(session_pid) do
      publish_heartbeat(realm, device_id)

      setup_heartbeat_timer(realm, device_id, session_pid)
    else
      # The session is not alive anymore, just stop
      :ok
    end
  end

  def ack_device_deletion(realm_name, encoded_device_id) do
    timestamp = now_us_x10_timestamp()
    publish_internal_message(realm_name, encoded_device_id, "/f", "", timestamp)
    {:ok, decoded_device_id} = Device.decode_device_id(encoded_device_id)
    {:ok, _} = Queries.ack_device_deletion(realm_name, decoded_device_id)
    :ok
  end

  defp setup_heartbeat_timer(realm, device_id, session_pid) do
    args = [realm, device_id, session_pid]
    interval = Config.device_heartbeat_interval_ms() |> randomize_interval(0.25)
    {:ok, _timer} = :timer.apply_after(interval, __MODULE__, :handle_heartbeat, args)

    :ok
  end

  defp randomize_interval(interval, tolerance) do
    multiplier = 1 + (tolerance * 2 * :rand.uniform() - tolerance)

    (interval * multiplier)
    |> Float.round()
    |> trunc()
  end

  defp publish_introspection(realm, device_id, payload, timestamp) do
    publish(realm, device_id, payload, "introspection", timestamp)
  end

  defp publish_data(realm, device_id, interface, path, payload, timestamp) do
    additional_headers = [x_astarte_interface: interface, x_astarte_path: path]

    publish(realm, device_id, payload, "data", timestamp, additional_headers)
  end

  defp publish_capabilities(realm, device_id, payload, timestamp) do
    publish(realm, device_id, payload, "capabilities", timestamp)
  end

  defp publish_control_message(realm, device_id, control_path, payload, timestamp) do
    additional_headers = [x_astarte_control_path: control_path]

    publish(realm, device_id, payload, "control", timestamp, additional_headers)
  end

  defp publish_internal_message(realm, device_id, internal_path, payload, timestamp) do
    additional_headers = [x_astarte_internal_path: internal_path]

    publish(realm, device_id, payload, "internal", timestamp, additional_headers)
  end

  def publish_event(client_id, event_string, timestamp, additional_headers \\ []) do
    case String.split(client_id, "/") do
      [realm, device_id] ->
        publish(realm, device_id, "", event_string, timestamp, additional_headers)

      # Not a device, ignoring it
      _ ->
        :ok
    end
  end

  defp publish_heartbeat(realm, device_id) do
    timestamp = now_us_x10_timestamp()

    publish_internal_message(realm, device_id, "/heartbeat", "", timestamp)
  end

  defp publish(realm, device_id, payload, event_string, timestamp, additional_headers \\ []) do
    headers =
      [
        x_astarte_vmqamqp_proto_ver: 1,
        x_astarte_realm: realm,
        x_astarte_device_id: device_id,
        x_astarte_msg_type: event_string
      ] ++ additional_headers

    message_id = generate_message_id(realm, device_id, timestamp)

    {:ok, decoded_device_id} = Device.decode_device_id(device_id, allow_extended_id: true)

    sharding_key = {realm, decoded_device_id}

    publish_opts = [
      headers: headers,
      message_id: message_id,
      timestamp: timestamp,
      sharding_key: sharding_key
    ]

    :ok = EventsProducer.publish(payload, publish_opts)
  end

  defp now_us_x10_timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix(:microsecond)
    |> Kernel.*(10)
  end

  defp generate_message_id(realm, device_id, timestamp) do
    realm_trunc = String.slice(realm, 0..63)
    device_id_trunc = String.slice(device_id, 0..15)
    timestamp_hex_str = Integer.to_string(timestamp, 16)
    rnd = Enum.random(0..@max_rand) |> Integer.to_string(16)

    "#{realm_trunc}-#{device_id_trunc}-#{timestamp_hex_str}-#{rnd}"
  end

  defp get_connection_synchronizer_process!(client_id) do
    case SynchronizerSupervisor.start_child(client_id: client_id) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  defp authorize_registration(mountpoint, username) do
    [realm, device_id] = String.split(username, "/")
    {:ok, decoded_device_id} = Device.decode_device_id(device_id, allow_extended_id: true)

    cond do
      not device_exists?(realm, decoded_device_id) ->
        {:error, :device_does_not_exist}

      device_deletion_in_progress?(realm, decoded_device_id) ->
        {:error, :device_deletion_in_progress}

      true ->
        {:ok, registration_modifiers(mountpoint, username)}
    end
  end

  defp registration_modifiers(mountpoint, username) do
    # TODO: we probably want some of these values to be configurable in some way
    [
      subscriber_id: {mountpoint, username},
      max_inflight_messages: 100,
      max_message_size: 65_535,
      retry_interval: 20_000,
      upgrade_qos: false
    ]
  end

  defp device_exists?(realm, device_id) do
    case Queries.check_if_device_exists(realm, device_id) do
      {:ok, result} ->
        result

      {:error, :invalid_realm_name} ->
        false

      # Allow a device to connect even if right now the DB is not available
      {:error, %Xandra.ConnectionError{}} ->
        true

      # Allow a device to connect even if right now the DB is not available
      {:error, %Xandra.Error{}} ->
        true
    end
  end

  defp device_deletion_in_progress?(realm, device_id) do
    case Queries.check_device_deletion_in_progress(realm, device_id) do
      {:ok, result} ->
        result

      {:error, :invalid_realm_name} ->
        false

      {:error, %Xandra.ConnectionError{}} ->
        # Be conservative: if the device is not being deleted but we can't reach the
        # DB, it will try to connect again when DB is available
        true

      {:error, %Xandra.Error{}} ->
        # Be conservative: if the device is not being deleted but we can't reach the
        # DB, it will try to connect again when DB is available
        true
    end
  end
end
