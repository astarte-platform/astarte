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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.VMQ.Plugin.RPC.Server do
  @moduledoc false
  alias Astarte.VMQ.Plugin
  alias Astarte.VMQ.Plugin.Publisher

  use GenServer
  require Logger

  # Public API

  def start_link(args, opts \\ []) do
    name = {:via, Horde.Registry, {Registry.VMQPluginRPC, :server}}
    opts = Keyword.put(opts, :name, name)

    GenServer.start_link(__MODULE__, args, opts)
  end

  # Callbacks

  @impl GenServer
  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:disconnect, %{client_id: nil}}, _from, state) do
    Logger.warning("Disconnect with empty client id.", tag: "disconnect_empty_client_id")
    {:reply, {:error, :empty_client_id}, state}
  end

  @impl GenServer
  def handle_call({:disconnect, %{discard_state: nil}}, _from, state) do
    Logger.warning("Disconnect with empty discard state.", tag: "disconnect_empty_discard_state")
    {:reply, {:error, :empty_discard_state}, state}
  end

  @impl GenServer
  def handle_call(
        {:disconnect, %{client_id: client_id, discard_state: discard_state}},
        _from,
        state
      ) do
    answer = Plugin.disconnect_client(client_id, discard_state)
    {:reply, answer, state}
  end

  @impl GenServer
  def handle_call({:delete, %{realm_name: realm, device_id: device}}, _from, state) do
    client_id = "#{realm}/#{device}"
    # Either the client has been deleted or it is :not_found,
    # which means that there is no session anyway.
    Plugin.disconnect_client(client_id, true)
    Plugin.ack_device_deletion(realm, device)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:publish, %{topic_tokens: []}}, _from, state) do
    _ = Logger.warning("Publish with empty topic tokens", tag: "publish_empty_topic_tokens")

    {:reply, {:error, :empty_topic_tokens}, state}
  end

  # This also handles the case of qos == nil, that is > 2
  @impl GenServer
  def handle_call({:publish, %{qos: qos}}, _from, state) when qos > 2 or qos < 0 do
    _ = Logger.warning("Publish with invalid QoS", tag: "publish_invalid_qos")

    {:reply, {:error, :invalid_qos}, state}
  end

  @impl GenServer
  def handle_call(
        {:publish, %{topic_tokens: topic_tokens, payload: payload, qos: qos}},
        _from,
        state
      ) do
    answer =
      case Publisher.publish(topic_tokens, payload, qos) do
        {:ok, {local_matches, remote_matches}} ->
          {:ok, %{local_matches: local_matches, remote_matches: remote_matches}}

        {:error, reason} ->
          Logger.warning("Publish failed with reason: #{inspect(reason)}", tag: "publish_failed")
          {:error, reason}

        other_err ->
          Logger.warning("Unknown error in publish: #{inspect(other_err)}",
            tag: "publish_failed_unknown_error"
          )

          {:error, :publish_error}
      end

    {:reply, answer, state}
  end

  # Horde dynamic supervisor signals

  @impl GenServer
  def handle_info(
        {:EXIT, _pid, {:name_conflict, {_name, _value}, _registry, _winning_pid}},
        state
      ) do
    _ =
      Logger.warning(
        "Received a :name_conflict signal from the outer space, maybe a netsplit occurred? Gracefully shutting down.",
        tag: "RPC exit"
      )

    {:stop, :shutdown, state}
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, :shutdown}, state) do
    _ =
      Logger.warning(
        "Received a :shutdown signal from the outer space, maybe the supervisor is mad? Gracefully shutting down.",
        tag: "RPC exit"
      )

    {:stop, :shutdown, state}
  end
end
