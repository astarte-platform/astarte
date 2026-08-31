#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.Rooms.Room do
  @moduledoc """
  Genserver representing a real-time communication room.

  Rooms act as dynamic bridges between Astarte devices/groups and connected clients.
  They manage volatile triggers, monitor clients connections, and handle the
  broadcasting of events over channels.
  """
  use GenServer, restart: :transient

  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.API.Rooms.WatchRequest
  alias Astarte.AppEngine.API.Utils
  alias Astarte.AppEngine.APIWeb.Endpoint
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.RPC.VolatileTriggers

  require Logger

  # API

  def start_link(args) do
    with {:ok, room_name} <- Keyword.fetch(args, :room_name),
         true <- Keyword.has_key?(args, :realm),
         {:ok, pid} <- GenServer.start_link(__MODULE__, args, name: via_tuple(room_name)) do
      {:ok, pid}
    else
      :error ->
        # No room_name in args
        {:error, :no_room_name}

      false ->
        # No realm name in args
        {:error, :no_realm_name}

      {:error, {:already_started, pid}} ->
        # Already started, we don't care
        {:ok, pid}

      other ->
        # Relay everything else
        other
    end
  end

  def join(room_name) do
    via_tuple(room_name)
    |> GenServer.call(:join)
  end

  def clients_count(room_name) do
    via_tuple(room_name)
    |> GenServer.call(:clients_count)
  end

  def watch(room_name, %WatchRequest{} = watch_request) do
    via_tuple(room_name)
    |> GenServer.call({:watch, watch_request})
  end

  def unwatch(room_name, watch_name) do
    via_tuple(room_name)
    |> GenServer.call({:unwatch, watch_name})
  end

  def broadcast_event(pid, trigger_id, device_id, timestamp, event) do
    GenServer.call(pid, {:broadcast_event, trigger_id, device_id, timestamp, event})
  end

  # Callbacks

  @impl true
  def init(args) do
    room_name = Keyword.get(args, :room_name)
    realm = Keyword.get(args, :realm)
    room_uuid = Utils.get_uuid()

    {:ok, _} = Registry.register(Registry.AstarteRooms, {:parent_trigger_id, room_uuid}, [])

    :telemetry.execute(
      [:astarte, :appengine, :channels, :room_opened],
      %{},
      %{realm: realm}
    )

    {:ok,
     %{
       clients: MapSet.new(),
       realm: realm,
       room_name: room_name,
       room_uuid: room_uuid,
       watch_id_to_request: %{},
       watch_name_to_id: %{}
     }}
  end

  @impl true
  def handle_call(:join, {pid, _tag} = _from, %{clients: clients} = state) do
    if MapSet.member?(clients, pid) do
      {:reply, {:error, :already_joined}, state}
    else
      Process.monitor(pid)
      {:reply, :ok, %{state | clients: MapSet.put(clients, pid)}}
    end
  end

  def handle_call(:clients_count, _from, %{clients: clients} = state) do
    {:reply, MapSet.size(clients), state}
  end

  def handle_call({:watch, watch_request}, _from, state) do
    %{
      watch_name_to_id: watch_name_to_id
    } = state

    :telemetry.execute(
      [:astarte, :appengine, :channels, :watch_request],
      %{},
      %{realm: state.realm}
    )

    with {:duplicate, false} <- {:duplicate, Map.has_key?(watch_name_to_id, watch_request.name)},
         {:ok, new_state} <- do_watch(watch_request, state) do
      {:reply, :ok, new_state}
    else
      {:duplicate, true} ->
        {:reply, {:error, :duplicate_watch}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unwatch, watch_name}, _from, state) do
    %{
      watch_id_to_request: watch_id_to_request,
      watch_name_to_id: watch_name_to_id
    } = state

    :telemetry.execute(
      [:astarte, :appengine, :channels, :unwatch_request],
      %{},
      %{realm: state.realm}
    )

    with {:ok, trigger_id} <- Map.fetch(watch_name_to_id, watch_name),
         {:ok, %WatchRequest{} = watch_request} <- Map.fetch(watch_id_to_request, trigger_id),
         {:ok, new_state} <- do_unwatch(watch_request, trigger_id, state) do
      {:reply, :ok, new_state}
    else
      :error ->
        {:reply, {:error, :not_found}, state}

      {:error, reason} ->
        _ =
          Logger.warning("Volatile trigger delete failed, reason: #{inspect(reason)}.",
            tag: "delete_volatile_trigger_failed"
          )

        {:reply, {:error, :unwatch_failed}, state}
    end
  end

  def handle_call({:broadcast_event, trigger_id, device_id, timestamp, event}, _from, state) do
    %{room_name: room_name, watch_id_to_request: watch_id_to_request} = state

    reply =
      if Map.has_key?(watch_id_to_request, trigger_id) do
        payload = %{
          "device_id" => device_id,
          "timestamp" => timestamp,
          "event" => event
        }

        :telemetry.execute(
          [:astarte, :appengine, :channels, :event_sent],
          %{},
          %{realm: state.realm}
        )

        Endpoint.broadcast("rooms:" <> room_name, "new_event", payload)
      else
        {:error, :trigger_not_found}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{clients: clients} = state) do
    new_clients = MapSet.delete(clients, pid)

    if Enum.empty?(new_clients) do
      room_cleanup(state)

      :telemetry.execute(
        [:astarte, :appengine, :channels, :room_closed],
        %{},
        %{realm: state.realm}
      )

      {:stop, :normal, %{state | watch_id_to_request: %{}, watch_name_to_id: %{}}}
    else
      {:noreply, %{state | clients: new_clients}}
    end
  end

  defp do_watch(watch_request, state) do
    %{
      watch_id_to_request: watch_id_to_request,
      room_uuid: room_uuid,
      watch_name_to_id: watch_name_to_id,
      realm: realm
    } = state

    %WatchRequest{
      name: name,
      simple_trigger: simple_trigger_config
    } = watch_request

    trigger_id = Utils.get_uuid()
    tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(simple_trigger_config)

    amqp_trigger_target = %AMQPTriggerTarget{
      simple_trigger_id: trigger_id,
      parent_trigger_id: room_uuid,
      routing_key: Config.rooms_events_routing_key!()
    }

    case VolatileTriggers.install(realm, tagged_simple_trigger, amqp_trigger_target) do
      :ok ->
        new_state = %{
          state
          | watch_id_to_request: Map.put(watch_id_to_request, trigger_id, watch_request),
            watch_name_to_id: Map.put(watch_name_to_id, name, trigger_id)
        }

        {:ok, new_state}

      {:error, reason} ->
        _ =
          Logger.warning("Volatile trigger install failed, reason: #{inspect(reason)}.",
            tag: "install_volatile_trigger_failed"
          )

        {:error, reason}
    end
  end

  defp do_unwatch(watch_request, trigger_id, state) do
    %{
      watch_id_to_request: watch_id_to_request,
      watch_name_to_id: watch_name_to_id,
      realm: realm
    } = state

    %WatchRequest{
      name: watch_name
    } = watch_request

    with :ok <- VolatileTriggers.delete(realm, trigger_id) do
      new_state = %{
        state
        | watch_id_to_request: Map.delete(watch_id_to_request, trigger_id),
          watch_name_to_id: Map.delete(watch_name_to_id, watch_name)
      }

      {:ok, new_state}
    end
  end

  defp room_cleanup(%{watch_id_to_request: watch_id_to_request} = state) do
    Enum.each(watch_id_to_request, fn {trigger_id, watch_request} ->
      do_unwatch(watch_request, trigger_id, state)
    end)
  end

  # Helpers

  defp via_tuple(room_name) do
    {:via, Registry, {Registry.AstarteRooms, room_name}}
  end
end
