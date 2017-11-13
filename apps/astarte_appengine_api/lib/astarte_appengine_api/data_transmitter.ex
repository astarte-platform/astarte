defmodule Astarte.AppEngine.API.DataTransmitter do
  @moduledoc """
  This module allows Astarte to push data to the devices
  """

  alias Astarte.AppEngine.API.DataTransmitter.MQTTClient

  @doc false
  defimpl Bson.Encoder.Protocol, for: DateTime do
    def encode(datetime) do
      ms = DateTime.to_unix(datetime, :milliseconds)

      %Bson.UTC{ms: ms}
      |> Bson.Encoder.Protocol.encode()
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

    bson_payload =
      make_payload_map(payload, timestamp, metadata)
      |> Bson.encode()

    topic = make_topic(realm, device_id, interface, path)

    MQTTClient.publish(topic, bson_payload)
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

    MQTTClient.publish(topic, bson_payload)
  end

  @doc """
  Pushes an unset message on a properties interface.
  """
  def unset_property(realm, device_id, interface, path) do
    topic = make_topic(realm, device_id, interface, path)

    MQTTClient.publish(topic, "")
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
    "#{realm}/#{device_id}/#{interface}#{path_with_slash}"
  end

  defp make_topic(realm, device_id, interface, no_slash_path) do
    "#{realm}/#{device_id}/#{interface}/#{no_slash_path}"
  end
end
