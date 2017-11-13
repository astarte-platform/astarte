defmodule Astarte.AppEngine.API.DataTransmitter.MQTTClient do
  use GenMQTT

  @exactly_once_qos 2

  def start_link(opts \\ []) do
    GenMQTT.start_link(__MODULE__, [], Keyword.put(opts, :name, __MODULE__))
  end

  def publish(topic, payload) do
    GenMQTT.publish(__MODULE__, topic, payload, @exactly_once_qos, false)
  end
end
