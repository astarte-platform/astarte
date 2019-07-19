#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

  alias Astarte.RPC.Protocol.DataUpdaterPlant, as: Protocol
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

  @dup_rpc_destination Protocol.amqp_queue()

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

  @error_string "unsupported_interface_aggregation"
  @encoded_generic_error_reply %Reply{
                                 error: true,
                                 reply:
                                   {:generic_error_reply,
                                    %GenericErrorReply{error_name: @error_string}}
                               }
                               |> Reply.encode()

  @event_simple_trigger_id Utils.get_uuid()
  @event_value 1000

  @simple_event %SimpleEvent{
    simple_trigger_id: @event_simple_trigger_id,
    # Populated in tests
    parent_trigger_id: nil,
    realm: @realm,
    device_id: @device_id,
    event: {
      :incoming_data_event,
      %IncomingDataEvent{
        interface: @interface_exact,
        path: @path,
        bson_value: Cyanide.encode!(%{v: @event_value})
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
    setup [:join_socket_and_authorize_watch, :verify_on_exit!]

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
      |> expect(:rpc_call, fn _serialized_call, @dup_rpc_destination ->
        {:ok, @encoded_generic_error_reply}
      end)

      watch_payload = %{
        "device_id" => @device_id,
        "name" => @name,
        "simple_trigger" => @data_simple_trigger
      }

      ref = push(socket, "watch", watch_payload)
      assert_reply ref, :error, %{reason: @error_string}
    end

    test "succeeds on authorized exact path", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call, @dup_rpc_destination ->
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

      watch_cleanup(socket, @name)
    end

    test "fails on duplicate", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call, @dup_rpc_destination ->
        assert %Call{call: {:install_volatile_trigger, %InstallVolatileTrigger{} = install_call}} =
                 Call.decode(serialized_call)

        assert %InstallVolatileTrigger{
                 realm_name: @realm,
                 device_id: @device_id
               } = install_call

        {:ok, @encoded_generic_ok_reply}
      end)
      |> stub(:rpc_call, fn _serialized_call, @dup_rpc_destination ->
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

      watch_cleanup(socket, @name)
    end

    test "succeeds on authorized regex path", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call, @dup_rpc_destination ->
        assert %Call{call: {:install_volatile_trigger, %InstallVolatileTrigger{} = install_call}} =
                 Call.decode(serialized_call)

        assert %InstallVolatileTrigger{
                 realm_name: @realm,
                 device_id: @device_id
               } = install_call

        {:ok, @encoded_generic_ok_reply}
      end)
      |> stub(:rpc_call, fn _serialized_call, @dup_rpc_destination ->
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

      watch_cleanup(socket, @name)
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
      |> expect(:rpc_call, fn serialized_call, @dup_rpc_destination ->
        assert %Call{call: {:install_volatile_trigger, %InstallVolatileTrigger{} = install_call}} =
                 Call.decode(serialized_call)

        assert %InstallVolatileTrigger{
                 realm_name: @realm,
                 device_id: @device_id
               } = install_call

        {:ok, @encoded_generic_ok_reply}
      end)
      |> stub(:rpc_call, fn _serialized_call, @dup_rpc_destination ->
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

      watch_cleanup(socket, @name)
    end
  end

  describe "unwatch" do
    setup [:join_socket_and_authorize_watch, :verify_on_exit!]

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
      |> expect(:rpc_call, fn _serialized_install, @dup_rpc_destination ->
        {:ok, @encoded_generic_ok_reply}
      end)
      |> expect(:rpc_call, fn _serialized_delete, @dup_rpc_destination ->
        {:ok, @encoded_generic_error_reply}
      end)
      |> stub(:rpc_call, fn _serialized_call, @dup_rpc_destination ->
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
      assert_reply ref, :error, %{reason: "unwatch failed"}

      watch_cleanup(socket, @name)
    end

    test "succeeds with valid name", %{socket: socket, room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn _serialized_install, @dup_rpc_destination ->
        {:ok, @encoded_generic_ok_reply}
      end)
      |> expect(:rpc_call, fn _serialized_delete, @dup_rpc_destination ->
        {:ok, @encoded_generic_ok_reply}
      end)
      |> stub(:rpc_call, fn _serialized_call, @dup_rpc_destination ->
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
    setup [:join_socket_and_authorize_watch, :verify_on_exit!]

    test "an event directed towards an unexisting room uninstalls the trigger", %{
      room_process: room_process
    } do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call, @dup_rpc_destination ->
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
      |> stub(:rpc_call, fn _serialized_call, @dup_rpc_destination ->
        {:ok, @encoded_generic_ok_reply}
      end)

      unexisting_room_serialized_event =
        %{@simple_event | parent_trigger_id: Utils.get_uuid()}
        |> SimpleEvent.encode()

      assert {:error, :no_room_for_event} =
               EventsDispatcher.dispatch(unexisting_room_serialized_event)

      refute_broadcast "new_event", %{"device_id" => @device_id, "event" => _event}
    end

    test "an event for an unwatched trigger uninstalls the trigger and doesn't trigger a broadcast",
         %{room_process: room_process} do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call, @dup_rpc_destination ->
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

      %{room_uuid: room_uuid} = :sys.get_state(room_process)

      existing_room_serialized_event =
        %{@simple_event | parent_trigger_id: room_uuid}
        |> SimpleEvent.encode()

      assert {:error, :trigger_not_found} =
               EventsDispatcher.dispatch(existing_room_serialized_event)

      refute_broadcast "new_event", %{"device_id" => @device_id, "event" => _event}
    end

    test "an event for a watched trigger belonging to a room triggers a broadcast", %{
      socket: socket,
      room_process: room_process
    } do
      MockRPCClient
      |> allow(self(), room_process)
      |> expect(:rpc_call, fn serialized_call, @dup_rpc_destination ->
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

      %{room_uuid: room_uuid, watch_id_to_request: watch_map} = :sys.get_state(room_process)

      [simple_trigger_id | _] = Map.keys(watch_map)

      existing_room_serialized_event =
        %{@simple_event | parent_trigger_id: room_uuid, simple_trigger_id: simple_trigger_id}
        |> SimpleEvent.encode()

      assert :ok = EventsDispatcher.dispatch(existing_room_serialized_event)
      assert_broadcast "new_event", %{"device_id" => @device_id, "event" => event}

      assert %{
               "type" => "incoming_data",
               "interface" => @interface_exact,
               "path" => @path,
               "value" => @event_value
             }
             |> Jason.encode() == Jason.encode(event)

      watch_cleanup(socket, @name)
    end
  end

  defp room_join_authorized_socket(_context) do
    token = JWTTestHelper.gen_channels_jwt_token(["JOIN::#{@authorized_room_name}"])
    {:ok, socket} = connect(UserSocket, %{"realm" => @realm, "token" => token})

    {:ok, socket: socket}
  end

  defp join_socket_and_authorize_watch(_context) do
    MockRPCClient
    |> stub(:rpc_call, fn _, @dup_rpc_destination ->
      {:ok, @encoded_generic_ok_reply}
    end)

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

    {:ok, socket: socket, room_process: room_process}
  end

  defp room_process(room_name) do
    case Registry.lookup(Registry.AstarteRooms, room_name) do
      [{pid, _opts}] -> pid
    end
  end

  defp watch_cleanup(socket, watch_name) do
    # Manually cleanup watches to avoid MockRPC complaining about missing
    # expectations due to the socket terminating (and cleaning up watches)
    # after Mox on_exit callback has already been called (and expectations emptied)
    payload = %{"name" => watch_name}
    ref = push(socket, "unwatch", payload)
    assert_broadcast "watch_removed", _
    assert_reply ref, :ok, %{}
  end
end
