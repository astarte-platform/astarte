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

defmodule Astarte.AppEngine.APIWeb.RoomsChannel do
  use Astarte.AppEngine.APIWeb, :channel

  alias Astarte.AppEngine.API.Auth.RoomsUser

  def join("rooms:" <> room_name, _payload, socket) do
    user = socket.assigns[:user]
    realm = socket.assigns[:realm]

    if join_authorized?(room_name, user, realm) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (rooms:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
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
end
