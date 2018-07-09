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

defmodule Astarte.AppEngine.APIWeb.DataTransmitterTest do
  use Astarte.AppEngine.APIWeb.ChannelCase

  alias Astarte.RPC.Protocol.VMQ.Plugin, as: Protocol

  alias Astarte.RPC.Protocol.VMQ.Plugin.{
    Call,
    GenericOkReply,
    Publish,
    Reply
  }

  alias Astarte.AppEngine.API.DataTransmitter

  import Mox

  @vmq_plugin_destination Protocol.amqp_queue()

  @realm "myrealm"
  @device_id <<35, 1, 71, 23, 239, 218, 73, 15, 166, 214, 106, 110, 62, 242, 13, 123>>
  @encoded_device_id "IwFHF-_aSQ-m1mpuPvINew"
  @interface "com.My.Interface"
  @path "/my/path"
  @path_tokens String.split(@path, "/", trim: true)
  @payload "importantdata"
  @timestamp DateTime.utc_now()
  @metadata %{some: "metadata"}

  @encoded_generic_ok_reply %Reply{
                              reply: {:generic_ok_reply, %GenericOkReply{}}
                            }
                            |> Reply.encode()

  test "datastream push with no opts" do
    MockRPCClient
    |> expect(:rpc_call, fn serialized_call, @vmq_plugin_destination ->
      assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

      encoded_payload = Bson.encode(%{v: @payload})

      assert %Publish{
               topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
               payload: ^encoded_payload,
               qos: 0
             } = publish_call

      {:ok, @encoded_generic_ok_reply}
    end)

    assert :ok = DataTransmitter.push_datastream(@realm, @device_id, @interface, @path, @payload)
  end

  test "datastream push with opts" do
    MockRPCClient
    |> expect(:rpc_call, fn serialized_call, @vmq_plugin_destination ->
      assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

      encoded_payload = Bson.encode(%{v: @payload, m: @metadata, t: @timestamp})

      assert %Publish{
               topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
               payload: ^encoded_payload,
               qos: 1
             } = publish_call

      {:ok, @encoded_generic_ok_reply}
    end)

    opts = [metadata: @metadata, timestamp: @timestamp, qos: 1]

    assert :ok =
             DataTransmitter.push_datastream(
               @realm,
               @device_id,
               @interface,
               @path,
               @payload,
               opts
             )
  end

  test "set property with no opts" do
    MockRPCClient
    |> expect(:rpc_call, fn serialized_call, @vmq_plugin_destination ->
      assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

      encoded_payload = Bson.encode(%{v: @payload})

      assert %Publish{
               topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
               payload: ^encoded_payload,
               qos: 2
             } = publish_call

      {:ok, @encoded_generic_ok_reply}
    end)

    assert :ok = DataTransmitter.set_property(@realm, @device_id, @interface, @path, @payload)
  end

  test "set property with opts" do
    MockRPCClient
    |> expect(:rpc_call, fn serialized_call, @vmq_plugin_destination ->
      assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

      encoded_payload = Bson.encode(%{v: @payload, m: @metadata, t: @timestamp})

      assert %Publish{
               topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
               payload: ^encoded_payload,
               qos: 2
             } = publish_call

      {:ok, @encoded_generic_ok_reply}
    end)

    opts = [metadata: @metadata, timestamp: @timestamp]

    assert :ok =
             DataTransmitter.set_property(
               @realm,
               @device_id,
               @interface,
               @path,
               @payload,
               opts
             )
  end

  test "unset property" do
    MockRPCClient
    |> expect(:rpc_call, fn serialized_call, @vmq_plugin_destination ->
      assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

      assert %Publish{
               topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
               payload: <<>>,
               qos: 2
             } = publish_call

      {:ok, @encoded_generic_ok_reply}
    end)

    assert :ok = DataTransmitter.unset_property(@realm, @device_id, @interface, @path)
  end
end
