defmodule Astarte.AppEngine.API.DataTransmitter.MQTTClient do
  use GenMQTT

  def start_link(opts \\ []) do
    GenMQTT.start_link(__MODULE__, [], Keyword.put(opts, :name, __MODULE__))
  end
end
