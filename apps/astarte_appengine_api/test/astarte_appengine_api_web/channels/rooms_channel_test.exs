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

      assert {:ok, socket} = connect(UserSocket, %{"realm" => "autotestrealm", "token" => token})

      assert %RoomsUser{
               join_authorizations: [@all_access_regex],
               watch_authorizations: [@all_access_regex]
             } = socket.assigns[:user]
    end
  end
end
