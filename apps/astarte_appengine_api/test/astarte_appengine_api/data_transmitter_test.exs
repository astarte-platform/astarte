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
