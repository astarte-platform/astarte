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

defmodule Astarte.AppEngine.APIWeb.RoomsChannelTest do
  use Astarte.AppEngine.APIWeb.ChannelCase

  alias Astarte.AppEngine.API.Auth.RoomsUser
  alias Astarte.AppEngine.API.DatabaseTestHelper
  alias Astarte.AppEngine.API.JWTTestHelper
  alias Astarte.AppEngine.APIWeb.RoomsChannel
  alias Astarte.AppEngine.APIWeb.UserSocket

  @all_access_regex ".*"
  @realm "autotestrealm"
  @authorized_room_name "letmein"

  @unauthorized_reason %{reason: "unauthorized"}

  setup_all do
    DatabaseTestHelper.create_public_key_only_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  describe "authentication" do
    test "connection with empty params fails" do
      assert :error = connect(UserSocket, %{})
    end

    test "connection with non-existing realm fails" do
      token = JWTTestHelper.gen_channels_jwt_all_access_token()

      assert :error = connect(UserSocket, %{"realm" => "nonexisting", "token" => token})
    end

    test "connection with valid realm and token succeeds" do
      token = JWTTestHelper.gen_channels_jwt_all_access_token()

      assert {:ok, socket} = connect(UserSocket, %{"realm" => @realm, "token" => token})

      assert %RoomsUser{
               join_authorizations: [@all_access_regex],
               watch_authorizations: [@all_access_regex]
             } = socket.assigns[:user]
    end
  end

  describe "join authorization" do
    setup [:room_join_authorized_socket]

    test "fails with different realm", %{socket: socket} do
      assert {:error, @unauthorized_reason} =
               join(socket, "rooms:otherrealm:#{@authorized_room_name}")
    end

    test "fails with unauthorized room", %{socket: socket} do
      assert {:error, @unauthorized_reason} =
               join(socket, "rooms:#{@realm}:unauthorized_room_name")
    end

    test "fails with empty auth token" do
      token = JWTTestHelper.gen_channels_jwt_token([])
      {:ok, socket} = connect(UserSocket, %{"realm" => @realm, "token" => token})

      assert {:error, @unauthorized_reason} =
               join(socket, "rooms:#{@realm}:#{@authorized_room_name}")
    end

    test "succeeds with correct realm and room name", %{socket: socket} do
      assert {:ok, _reply, _socket} = join(socket, "rooms:#{@realm}:#{@authorized_room_name}")
    end

    test "succeeds with all access token" do
      token = JWTTestHelper.gen_channels_jwt_all_access_token()
      {:ok, socket} = connect(UserSocket, %{"realm" => @realm, "token" => token})

      assert {:ok, _reply, _socket} = join(socket, "rooms:#{@realm}:#{@authorized_room_name}")
    end
  end

  defp room_join_authorized_socket(_context) do
    token = JWTTestHelper.gen_channels_jwt_token(["JOIN::#{@authorized_room_name}"])
    {:ok, socket} = connect(UserSocket, %{"realm" => @realm, "token" => token})

    {:ok, socket: socket}
  end
end
