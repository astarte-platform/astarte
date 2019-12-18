#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.DataTransmitter do
  alias Astarte.Core.Device

  @moduledoc """
  This module allows Astarte to push data to the devices
  """

  alias Astarte.AppEngine.API.RPC.VMQPlugin

  @property_qos 2

  @doc """
  Pushes a payload on a datastream interface.

  ## Options
  `opts` is a keyword list that can contain the following keys:
  * `timestamp`: a timestamp that is added in the BSON object inside the `t` key
  * `metadata`: a map of metadata that is added in the BSON object inside the `m` key
  """
  def push_datastream(realm, device_id, interface, path, payload, opts \\ []) do
    timestamp = Keyword.get(opts, :timestamp)
    metadata = Keyword.get(opts, :metadata)
    qos = Keyword.get(opts, :qos, 0)

    bson_payload =
      make_payload_map(payload, timestamp, metadata)
      |> Cyanide.encode!()

    topic = make_topic(realm, device_id, interface, path)

    VMQPlugin.publish(topic, bson_payload, qos)
  end

  @doc """
  Pushes a payload on a properties interface.

  ## Options
  `opts` is a keyword list that can contain the following keys:
  * `timestamp`: a timestamp that is added in the BSON object inside the `t` key
  * `metadata`: a map of metadata that is added in the BSON object inside the `m` key
  """
  def set_property(realm, device_id, interface, path, payload, opts \\ []) do
    timestamp = Keyword.get(opts, :timestamp)
    metadata = Keyword.get(opts, :metadata)

    bson_payload =
      make_payload_map(payload, timestamp, metadata)
      |> Cyanide.encode!()

    topic = make_topic(realm, device_id, interface, path)

    VMQPlugin.publish(topic, bson_payload, @property_qos)
  end

  @doc """
  Pushes an unset message on a properties interface.
  """
  def unset_property(realm, device_id, interface, path) do
    topic = make_topic(realm, device_id, interface, path)

    VMQPlugin.publish(topic, "", @property_qos)
  end

  defp make_payload_map(payload, nil, nil) do
    %{v: payload}
  end

  defp make_payload_map(payload, timestamp, nil) do
    %{v: payload, t: timestamp}
  end

  defp make_payload_map(payload, nil, metadata) do
    %{v: payload, m: metadata}
  end

  defp make_payload_map(payload, timestamp, metadata) do
    %{v: payload, t: timestamp, m: metadata}
  end

  defp make_topic(realm, device_id, interface, "/" <> _rest = path_with_slash) do
    encoded_device_id = Device.encode_device_id(device_id)

    "#{realm}/#{encoded_device_id}/#{interface}#{path_with_slash}"
  end

  defp make_topic(realm, device_id, interface, no_slash_path) do
    "#{realm}/#{device_id}/#{interface}/#{no_slash_path}"
  end
end
