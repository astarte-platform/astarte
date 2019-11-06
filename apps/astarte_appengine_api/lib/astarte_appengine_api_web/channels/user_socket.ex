#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.UserSocket do
  use Phoenix.Socket
  alias Astarte.AppEngine.API.Auth
  alias Astarte.AppEngine.API.Auth.RoomsUser
  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.APIWeb.SocketGuardian
  alias JOSE.JWK

  require Logger

  ## Channels
  channel "rooms:*", Astarte.AppEngine.APIWeb.RoomsChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(%{"realm" => realm} = payload, socket) do
    _ = Logger.debug("New socket connection request.")

    with token <- Map.get(payload, "token"),
         {:ok, %RoomsUser{} = user} <- authorized_user(realm, token) do
      authorized_socket =
        socket
        |> assign(:user, user)
        |> assign(:realm, realm)

      {:ok, authorized_socket}
    end
  end

  def connect(_params, _socket) do
    :error
  end

  defp authorized_user(realm, token) do
    if Config.authentication_disabled?() do
      {:ok, RoomsUser.all_access_user()}
    else
      authorized_user_from_token(realm, token)
    end
  end

  defp authorized_user_from_token(realm, token) do
    with {:ok, public_key} <- Auth.fetch_public_key(realm),
         %JWK{} = jwk <- JWK.from_pem(public_key),
         {:ok, %RoomsUser{} = user, _claims} <-
           SocketGuardian.resource_from_token(token, %{}, secret: jwk) do
      {:ok, user}
    else
      error ->
        _ = Logger.debug("Channels auth error: #{inspect(error)}.")
        :error
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Astarte.AppEngine.APIWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil
end
