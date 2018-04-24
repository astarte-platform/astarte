#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.AppEngine.API.Rooms.Room do
  use GenServer, restart: :transient

  alias Astarte.AppEngine.API.Rooms.WatchRequest
  alias Astarte.AppEngine.API.RPC.DataUpdaterPlant
  alias Astarte.AppEngine.API.RPC.VolatileTrigger
  alias Astarte.AppEngine.API.Utils
  alias Astarte.AppEngine.API.Config
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer

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

  # Callbacks

  @impl true
  def init(args) do
    room_name = Keyword.get(args, :room_name)
    realm = Keyword.get(args, :realm)

    {:ok,
     %{
       clients: MapSet.new(),
       realm: realm,
       room_name: room_name,
       room_uuid: Utils.get_uuid(),
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
      watch_id_to_request: watch_id_to_request,
      watch_name_to_id: watch_name_to_id,
      room_uuid: room_uuid,
      realm: realm
    } = state

    if Map.has_key?(watch_name_to_id, watch_request.name) do
      {:reply, {:error, :duplicate_watch}, state}
    else
      %WatchRequest{
        name: name,
        device_id: device_id,
        simple_trigger: simple_trigger_config
      } = watch_request

      %TaggedSimpleTrigger{
        object_id: object_id,
        object_type: object_type,
        simple_trigger_container: simple_trigger_container
      } = SimpleTriggerConfig.to_tagged_simple_trigger(simple_trigger_config)

      trigger_id = Utils.get_uuid()

      amqp_trigger_target = %AMQPTriggerTarget{
        simple_trigger_id: trigger_id,
        parent_trigger_id: room_uuid,
        routing_key: Config.rooms_events_routing_key()
      }

      trigger_target_container = %TriggerTargetContainer{
        trigger_target: {:amqp_trigger_target, amqp_trigger_target}
      }

      volatile_trigger = %VolatileTrigger{
        object_id: object_id,
        object_type: object_type,
        serialized_simple_trigger: SimpleTriggerContainer.encode(simple_trigger_container),
        parent_id: room_uuid,
        simple_trigger_id: trigger_id,
        serialized_trigger_target: TriggerTargetContainer.encode(trigger_target_container)
      }

      case DataUpdaterPlant.install_volatile_trigger(realm, device_id, volatile_trigger) do
        :ok ->
          {:reply, :ok,
           %{
             state
             | watch_id_to_request: Map.put(watch_id_to_request, trigger_id, watch_request),
               watch_name_to_id: Map.put(watch_name_to_id, name, trigger_id)
           }}

        {:error, reason} ->
          Logger.warn("install_volatile_trigger failed with reason: #{inspect(reason)}")
          {:reply, {:error, :watch_failed}, state}
      end
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{clients: clients} = state) do
    {:noreply, %{state | clients: MapSet.delete(clients, pid)}}
  end

  # Helpers

  defp via_tuple(room_name) do
    {:via, Registry, {RoomsRegistry, room_name}}
  end
end
