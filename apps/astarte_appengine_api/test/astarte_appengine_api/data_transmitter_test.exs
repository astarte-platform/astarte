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
  use Astarte.Cases.Conn

  alias Astarte.AppEngine.API.DataTransmitter

  import Mox

  @realm "myrealm"
  @device_id <<35, 1, 71, 23, 239, 218, 73, 15, 166, 214, 106, 110, 62, 242, 13, 123>>
  @encoded_device_id "IwFHF-_aSQ-m1mpuPvINew"
  @interface "com.My.Interface"
  @path "/my/path"
  @path_tokens String.split(@path, "/", trim: true)
  @payload "importantdata"
  @timestamp DateTime.utc_now()
  @metadata %{some: "metadata"}

  test "datastream push with no opts" do
    answer = {:ok, %{local_matches: 0, remote_matches: 0}}

    Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock
    |> expect(:publish, fn data ->
      encoded_payload = Cyanide.encode!(%{v: @payload})

      assert %{
               topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
               payload: ^encoded_payload,
               qos: 0
             } = data

      answer
    end)

    assert ^answer =
             DataTransmitter.push_datastream(@realm, @device_id, @interface, @path, @payload)
  end

  test "datastream push with opts" do
    answer = {:ok, %{local_matches: 0, remote_matches: 0}}

    Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock
    |> expect(:publish, fn data ->
      encoded_payload = Cyanide.encode!(%{v: @payload, m: @metadata, t: @timestamp})

      assert %{
               topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
               payload: ^encoded_payload,
               qos: 1
             } = data

      answer
    end)

    opts = [metadata: @metadata, timestamp: @timestamp, qos: 1]

    assert ^answer =
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
    answer = {:ok, %{local_matches: 0, remote_matches: 0}}

    Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock
    |> expect(:publish, fn data ->
      encoded_payload = Cyanide.encode!(%{v: @payload})

      assert %{
               topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
               payload: ^encoded_payload,
               qos: 2
             } = data

      answer
    end)

    assert ^answer = DataTransmitter.set_property(@realm, @device_id, @interface, @path, @payload)
  end

  test "set property with opts" do
    answer = {:ok, %{local_matches: 0, remote_matches: 0}}

    Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock
    |> expect(:publish, fn data ->
      encoded_payload = Cyanide.encode!(%{v: @payload, m: @metadata, t: @timestamp})

      %{
        topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
        payload: ^encoded_payload,
        qos: 2
      } = data

      answer
    end)

    opts = [metadata: @metadata, timestamp: @timestamp]

    assert ^answer =
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
    answer = {:ok, %{local_matches: 0, remote_matches: 0}}

    Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock
    |> expect(:publish, fn data ->
      %{
        topic_tokens: [@realm, @encoded_device_id, @interface | @path_tokens],
        payload: <<>>,
        qos: 2
      } = data

      answer
    end)

    assert ^answer = DataTransmitter.unset_property(@realm, @device_id, @interface, @path)
  end
end
