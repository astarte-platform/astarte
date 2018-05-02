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
  alias Astarte.AppEngine.API.Rooms.EventsDispatcher
  alias Astarte.AppEngine.API.Rooms.Room
  alias Astarte.AppEngine.API.Utils
  alias Astarte.AppEngine.APIWeb.RoomsChannel
  alias Astarte.AppEngine.APIWeb.UserSocket

  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent

  alias Astarte.RPC.Protocol.DataUpdaterPlant.Call
  alias Astarte.RPC.Protocol.DataUpdaterPlant.DeleteVolatileTrigger
  alias Astarte.RPC.Protocol.DataUpdaterPlant.GenericErrorReply
  alias Astarte.RPC.Protocol.DataUpdaterPlant.GenericOkReply
  alias Astarte.RPC.Protocol.DataUpdaterPlant.InstallVolatileTrigger
  alias Astarte.RPC.Protocol.DataUpdaterPlant.Reply

  import Mox

  @all_access_regex ".*"
  @realm "autotestrealm"
  @authorized_room_name "letmein"

  @device_id "9ZJmHWdwSjuXjPVaEMqkuA"
  @interface_exact "com.Some.Interface"
  @interface_regex "com.Some.Other.Interface"
  @path "/my/watched/path"
  @authorized_watch_path_exact "#{@device_id}/#{@interface_exact}#{@path}"
  @authorized_watch_path_regex "#{@device_id}/#{@interface_regex}.*"

  @name "testwatch"

  @data_simple_trigger %{
    "type" => "data_trigger",
    "interface_name" => @interface_exact,
    "interface_major" => 2,
    "on" => "incoming_data",
    "value_match_operator" => ">",
    "match_path" => @path,
    "known_value" => 42
  }

  @device_simple_trigger %{
    "type" => "device_trigger",
    "on" => "device_connected",
    "device_id" => @device_id
  }

  @unauthorized_reason %{reason: "unauthorized"}

  @encoded_generic_ok_reply %Reply{
    reply: {:generic_ok_reply, %GenericOkReply{async_operation: false}}
  }
  |> Reply.encode()

  @encoded_generic_error_reply %Reply{
    error: true,
    reply: {:generic_error_reply, %GenericErrorReply{error_name: "some_error"}}
  }
  |> Reply.encode()

  @event_simple_trigger_id Utils.get_uuid()
  @event_value 1000

  @simple_event %SimpleEvent{
    simple_trigger_id: @event_simple_trigger_id,
    parent_trigger_id: nil, # Populated in tests
    realm: @realm,
    device_id: @device_id,
    event: {
      :incoming_data_event,
      %IncomingDataEvent{
        interface: @interface_exact,
        path: @path,
        bson_value: Bson.encode(%{v: @event_value})
      }
    }
  }

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
      assert {:ok, _reply, socket} = join(socket, "rooms:#{@realm}:#{@authorized_room_name}")
      assert socket.assigns[:room_name] == "#{@realm}:#{@authorized_room_name}"
      assert Room.clients_count("#{@realm}:#{@authorized_room_name}") == 1
    end

    test "succeeds with all access token" do
      token = JWTTestHelper.gen_channels_jwt_all_access_token()
      {:ok, socket} = connect(UserSocket, %{"realm" => @realm, "token" => token})

      assert {:ok, _reply, socket} = join(socket, "rooms:#{@realm}:#{@authorized_room_name}")
      assert socket.assigns[:room_name] == "#{@realm}:#{@authorized_room_name}"
      assert Room.clients_count("#{@realm}:#{@authorized_room_name}") == 1
    end
  end

  describe "watch" do
    setup [:join_socket_and_authorize_watch]

    test "fails with invalid simple trigger", %{socket: socket} do
      invalid_simple_trigger_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => %{"type" => "invalid"}
      }

      ref = push(socket, "watch", invalid_simple_trigger_payload)
      assert_reply ref, :error, %{errors: _errors}
    end

    test "fails on unauthorized paths", %{socket: socket} do
      unauthorized_device_id = "0JS2C1qlTiS0JTmUC4vCKQ"

      unauthorized_device_id_payload = %{
        "device_id" => unauthorized_device_id,
        "name" => @name,
        "simple_trigger" => @data_simple_trigger
      }

      ref = push(socket, "watch", unauthorized_device_id_payload)
      assert_reply ref, :error, @unauthorized_reason

      unauthorized_interface =
        Map.put(@data_simple_trigger, "interface_name", "com.OtherInterface")

      unauthorized_interface_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => unauthorized_interface
      }

      ref = push(socket, "watch", unauthorized_interface_payload)
      assert_reply ref, :error, @unauthorized_reason
    end

    test "fails if RPC replies with an error", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn _serialized_call ->
        {:ok, @encoded_generic_error_reply}
      end)

      watch_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => @data_simple_trigger
      }

      ref = push(socket, "watch", watch_payload)
      assert_reply ref, :error, %{reason: "watch failed"}
    end

    test "succeeds on authorized exact path", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call ->
        assert %Call{call: {:install_volatile_trigger, %InstallVolatileTrigger{} = install_call}} =
                 Call.decode(serialized_call)

        assert %InstallVolatileTrigger{
                 realm_name: @realm,
                 device_id: @device_id
               } = install_call

        {:ok, @encoded_generic_ok_reply}
      end)

      watch_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => @data_simple_trigger
      }

      ref = push(socket, "watch", watch_payload)
      assert_broadcast "watch_added", _
      assert_reply ref, :ok, %{}
    end

    test "fails on duplicate", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call ->
        assert %Call{call: {:install_volatile_trigger, %InstallVolatileTrigger{} = install_call}} =
                 Call.decode(serialized_call)

        assert %InstallVolatileTrigger{
                 realm_name: @realm,
                 device_id: @device_id
               } = install_call

        {:ok, @encoded_generic_ok_reply}
      end)

      watch_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => @data_simple_trigger
      }

      ref = push(socket, "watch", watch_payload)
      assert_broadcast "watch_added", _
      assert_reply ref, :ok, %{}

      ref = push(socket, "watch", watch_payload)
      assert_reply ref, :error, %{reason: "already existing"}
    end

    test "succeeds on authorized regex path", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call ->
        assert %Call{call: {:install_volatile_trigger, %InstallVolatileTrigger{} = install_call}} =
                 Call.decode(serialized_call)

        assert %InstallVolatileTrigger{
                 realm_name: @realm,
                 device_id: @device_id
               } = install_call

        {:ok, @encoded_generic_ok_reply}
      end)

      regex_trigger =
        @data_simple_trigger
        |> Map.put("interface_name", @interface_regex)
        |> Map.put("match_path", "/a/random/path")

      watch_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => regex_trigger
      }

      ref = push(socket, "watch", watch_payload)
      assert_broadcast "watch_added", _
      assert_reply ref, :ok, %{}
    end

    test "fails on device_trigger with conflicting device_ids", %{socket: socket} do
      other_device_id = "0JS2C1qlTiS0JTmUC4vCKQ"

      wrong_device_id_trigger =
        @device_simple_trigger
        |> Map.put("device_id", other_device_id)

      conflicting_device_id_payload_1 = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => wrong_device_id_trigger
      }

      ref = push(socket, "watch", conflicting_device_id_payload_1)
      assert_reply ref, :error, @unauthorized_reason

      conflicting_device_id_payload_2 = %{
        "device_id" => other_device_id,
        "name" => @name,
        "simple_trigger" => @device_simple_trigger
      }

      ref = push(socket, "watch", conflicting_device_id_payload_2)
      assert_reply ref, :error, @unauthorized_reason
    end

    test "succeeds on authorized device_id", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call ->
        assert %Call{call: {:install_volatile_trigger, %InstallVolatileTrigger{} = install_call}} =
                 Call.decode(serialized_call)

        assert %InstallVolatileTrigger{
                 realm_name: @realm,
                 device_id: @device_id
               } = install_call

        {:ok, @encoded_generic_ok_reply}
      end)

      watch_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => @device_simple_trigger
      }

      ref = push(socket, "watch", watch_payload)
      assert_broadcast "watch_added", _
      assert_reply ref, :ok, %{}
    end
  end

  describe "unwatch" do
    setup [:join_socket_and_authorize_watch]

    test "fails with invalid params", %{socket: socket} do
      invalid_payload = %{}

      ref = push(socket, "unwatch", invalid_payload)
      assert_reply ref, :error, _
    end

    test "fails for non existing", %{socket: socket} do
      nonexisting_payload = %{"name" => "nonexisting"}

      ref = push(socket, "unwatch", nonexisting_payload)
      assert_reply ref, :error, %{reason: "not found"}
    end

    test "fails if RPC replies with an error", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn _serialized_install ->
          {:ok, @encoded_generic_ok_reply}
      end)
      |> expect(:rpc_call, fn _serialized_delete ->
          {:ok, @encoded_generic_error_reply}
      end)

      watch_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => @data_simple_trigger
      }

      ref = push(socket, "watch", watch_payload)
      assert_broadcast "watch_added", _
      assert_reply ref, :ok, %{}

      unwatch_payload = %{"name" => @name}

      ref = push(socket, "unwatch", unwatch_payload)
      assert_reply ref, :error, %{reason: "unwatch failed"}
    end

    test "succeeds with valid name", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn _serialized_install ->
          {:ok, @encoded_generic_ok_reply}
      end)
      |> expect(:rpc_call, fn _serialized_delete ->
          {:ok, @encoded_generic_ok_reply}
      end)

      watch_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => @data_simple_trigger
      }

      ref = push(socket, "watch", watch_payload)
      assert_broadcast "watch_added", _
      assert_reply ref, :ok, %{}

      unwatch_payload = %{"name" => @name}

      ref = push(socket, "unwatch", unwatch_payload)
      assert_broadcast "watch_removed", _
      assert_reply ref, :ok, %{}
    end
  end

  describe "incoming events" do
    setup [:join_socket_and_authorize_watch]

    test "an event directed towards an unexisting room uninstalls the trigger", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call ->
        assert %Call{
          call: {
            :delete_volatile_trigger,
            serialized_delete
          }
        } = Call.decode(serialized_call)

        assert %DeleteVolatileTrigger{
          realm_name: @realm,
          device_id: @device_id,
          trigger_id: @event_simple_trigger_id
        } = serialized_delete

        {:ok, @encoded_generic_ok_reply}
      end)

      unexisting_room_serialized_event =
        %{@simple_event | parent_trigger_id: Utils.get_uuid()}
        |> SimpleEvent.encode()

      assert :ok = EventsDispatcher.dispatch(unexisting_room_serialized_event)
    end

    test "an event belonging to a room triggers a broadcast", %{socket: socket, room_process: room_process}  do
      %{room_uuid: room_uuid} = :sys.get_state(room_process)

      existing_room_serialized_event =
        %{@simple_event | parent_trigger_id: room_uuid}
        |> SimpleEvent.encode()

      assert :ok = EventsDispatcher.dispatch(existing_room_serialized_event)
      assert_broadcast "new_event", %{"device_id" => @device_id, "event" => event}
      assert %{
        "type" => "incoming_data",
        "interface" => @interface_exact,
        "path" => @path,
        "value" => @event_value
      }
      |> Poison.encode() == Poison.encode(event)
    end
  end

  defp room_join_authorized_socket(_context) do
    token = JWTTestHelper.gen_channels_jwt_token(["JOIN::#{@authorized_room_name}"])
    {:ok, socket} = connect(UserSocket, %{"realm" => @realm, "token" => token})

    {:ok, socket: socket}
  end

  defp join_socket_and_authorize_watch(_context) do
    token =
      JWTTestHelper.gen_channels_jwt_token([
        "JOIN::#{@authorized_room_name}",
        "WATCH::#{@authorized_watch_path_exact}",
        "WATCH::#{@authorized_watch_path_regex}",
        "WATCH::#{@device_id}"
      ])

    room_name = "#{@realm}:#{@authorized_room_name}"
    {:ok, socket} = connect(UserSocket, %{"realm" => @realm, "token" => token})
    {:ok, _reply, socket} = subscribe_and_join(socket, RoomsChannel, "rooms:#{room_name}")

    room_process = room_process(room_name)

    on_exit fn ->
      GenServer.stop(room_process)
    end

    {:ok, socket: socket, room_process: room_process}
  end

  defp room_process(room_name) do
    case Registry.lookup(RoomsRegistry, room_name) do
      [{pid, _opts}] -> pid
    end
  end
end
