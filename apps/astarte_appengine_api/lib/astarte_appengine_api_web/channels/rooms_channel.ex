# Copyright 2018-2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.AppEngine.APIWeb.RoomsChannel do
  use Astarte.AppEngine.APIWeb, :channel

  alias Astarte.AppEngine.API.Auth.RoomsUser
  alias Astarte.AppEngine.API.Rooms.Room
  alias Astarte.AppEngine.API.Rooms.RoomsSupervisor
  alias Astarte.AppEngine.API.Rooms.UnwatchRequest
  alias Astarte.AppEngine.API.Rooms.WatchRequest
  alias Astarte.AppEngine.APIWeb.ChangesetView
  alias Astarte.AppEngine.APIWeb.WatchRequestView
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Phoenix.Socket

  def join("rooms:" <> room_name, _payload, socket) do
    user = socket.assigns[:user]
    realm = socket.assigns[:realm]

    with true <- join_authorized?(room_name, user, realm),
         :ok <- maybe_start_room(realm, room_name),
         :ok <- Room.join(room_name) do
      {:ok, Socket.assign(socket, :room_name, room_name)}
    else
      false ->
        # Join unauthorized
        {:error, %{reason: "unauthorized"}}

      {:error, :room_not_started} ->
        {:error, %{reason: "room can't be started"}}
    end
  end

  def handle_in("watch", payload, socket) do
    changeset = WatchRequest.changeset(%WatchRequest{}, payload)

    with {:ok, request} <- Ecto.Changeset.apply_action(changeset, :insert),
         user <- socket.assigns[:user],
         true <- watch_authorized?(request, user),
         :ok <- Room.watch(socket.assigns[:room_name], request) do
      payload = WatchRequestView.render("watch_request.json", %{watch_request: request})
      broadcast(socket, "watch_added", payload)
      {:reply, :ok, socket}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        # Malformed watch request
        response = ChangesetView.render("error.json", %{changeset: changeset})
        {:reply, {:error, response}, socket}

      false ->
        # watch_authorized? returned false
        {:reply, {:error, %{reason: "unauthorized"}}, socket}

      {:error, :duplicate_watch} ->
        {:reply, {:error, %{reason: "already existing"}}, socket}

      {:error, reason} ->
        # RPC error reply
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("unwatch", payload, socket) do
    changeset = UnwatchRequest.changeset(%UnwatchRequest{}, payload)

    # TODO: authorize unwatch?
    with {:ok, %UnwatchRequest{name: watch_name}} <-
           Ecto.Changeset.apply_action(changeset, :insert),
         :ok <- Room.unwatch(socket.assigns[:room_name], watch_name) do
      broadcast(socket, "watch_removed", %{name: watch_name})
      {:reply, :ok, socket}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        # Malformed watch request
        response = ChangesetView.render("error.json", %{changeset: changeset})
        {:reply, {:error, response}, socket}

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "not found"}}, socket}

      {:error, :unwatch_failed} ->
        # RPC error reply
        {:reply, {:error, %{reason: "unwatch failed"}}, socket}
    end
  end

  defp join_authorized?(room_name, %RoomsUser{join_authorizations: authorizations}, realm)
       when is_list(authorizations) and is_binary(realm) do
    Enum.any?(authorizations, fn auth_regex ->
      can_join_room?(room_name, realm, auth_regex)
    end)
  end

  defp can_join_room?(room_name, realm, room_regex) do
    case Regex.compile("^#{realm}:#{room_regex}$") do
      {:ok, join_regex} ->
        Regex.match?(join_regex, room_name)

      _ ->
        # If we're here we failed to compile a regex
        false
    end
  end

  defp maybe_start_room(realm, room_name) do
    if RoomsSupervisor.room_started?(room_name) do
      :ok
    else
      case RoomsSupervisor.start_room(realm, room_name) do
        {:ok, _pid} ->
          :ok

        {:error, _reason} ->
          {:error, :room_not_started}
      end
    end
  end

  defp watch_authorized?(%WatchRequest{} = request, %RoomsUser{} = user) do
    %RoomsUser{
      watch_authorizations: authorizations
    } = user

    %WatchRequest{
      simple_trigger: simple_trigger_config
    } = request

    case request do
      %WatchRequest{device_id: device_id} when is_binary(device_id) ->
        can_watch_simple_trigger_for_device?(simple_trigger_config, device_id, authorizations)

      %WatchRequest{group_name: group_name} when is_binary(group_name) ->
        can_watch_simple_trigger_for_group?(simple_trigger_config, group_name, authorizations)
    end
  end

  defp can_watch_simple_trigger_for_device?(
         %SimpleTriggerConfig{type: "data_trigger"} = trigger,
         device_id,
         watch_authorizations
       ) do
    %SimpleTriggerConfig{
      interface_name: interface_name,
      match_path: path
    } = trigger

    watch_path = "#{device_id}/#{interface_name}#{path}"

    Enum.any?(watch_authorizations, fn authz_string ->
      can_watch_path?(watch_path, authz_string)
    end)
  end

  defp can_watch_simple_trigger_for_device?(
         %SimpleTriggerConfig{type: "device_trigger"} = trigger,
         device_id,
         watch_authorizations
       ) do
    %SimpleTriggerConfig{
      device_id: trigger_device_id
    } = trigger

    if device_id == trigger_device_id do
      # We match on device_id for the events
      Enum.any?(watch_authorizations, fn authz_string ->
        can_watch_path?(device_id, authz_string)
      end)
    else
      # Conflicting device ids, reject
      false
    end
  end

  defp can_watch_simple_trigger_for_group?(
         %SimpleTriggerConfig{type: "data_trigger"} = trigger,
         group_name,
         watch_authorizations
       ) do
    %SimpleTriggerConfig{
      interface_name: interface_name,
      match_path: path
    } = trigger

    watch_path = "groups/#{group_name}/#{interface_name}#{path}"

    Enum.any?(watch_authorizations, fn authz_string ->
      can_watch_path?(watch_path, authz_string)
    end)
  end

  defp can_watch_simple_trigger_for_group?(
         %SimpleTriggerConfig{type: "device_trigger"},
         group_name,
         watch_authorizations
       ) do
    watch_path = "groups/#{group_name}"

    Enum.any?(watch_authorizations, fn authz_string ->
      can_watch_path?(watch_path, authz_string)
    end)
  end

  defp can_watch_path?(path, authz_string) do
    # TODO: compile regexes on socket auth?
    case Regex.compile("^#{authz_string}$") do
      {:ok, path_regex} ->
        Regex.match?(path_regex, path)

      _ ->
        # If we're here we failed to compile a regex
        false
    end
  end
end
