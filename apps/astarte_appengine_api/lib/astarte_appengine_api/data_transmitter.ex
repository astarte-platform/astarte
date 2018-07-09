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
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.AppEngine.API.DataTransmitter do
  alias Astarte.Core.Device

  @moduledoc """
  This module allows Astarte to push data to the devices
  """

  alias Astarte.AppEngine.API.RPC.VMQPlugin

  @property_qos 2

  @doc false
  defimpl Cyanide.Encoder, for: DateTime do
    def encode(datetime) do
      ms = DateTime.to_unix(datetime, :milliseconds)

      %Bson.UTC{ms: ms}
      |> Cyanide.Encoder.encode()
    end
  end

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
      |> Bson.encode()

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
      |> Bson.encode()

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
