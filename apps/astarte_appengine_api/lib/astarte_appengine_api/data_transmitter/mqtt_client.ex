defmodule Astarte.AppEngine.API.DataTransmitter.MQTTClient do
  use GenMQTT

  @exactly_once_qos 2

  def start_link(opts \\ []) do
    full_opts =
      opts
      |> Keyword.put(:name, __MODULE__)
      |> Keyword.put(:client, generate_client_id())

    GenMQTT.start_link(__MODULE__, [], full_opts)
  end

  def publish(topic, payload) do
    GenMQTT.publish(__MODULE__, topic, payload, @exactly_once_qos, false)
  end

  defp generate_client_id do
    :crypto.strong_rand_bytes(10)
    |> Base.encode16()
  end
end
