defmodule Astarte.DataUpdaterPlant.Config.AMQPProducerTransform do
  @moduledoc """
  This module contains utilities for DataUpdaterPlant Configuration
  """

  @doc """
  Transforms an AMQP option to something inheriting defaults
  """
  def transform(conf) do
    producer_options =
      Conform.Conf.get(conf, "astarte_data_updater_plant.amqp_producer_options.$option")
      |> Enum.reject(fn el -> match?({_, nil}, el) end)

    Conform.Conf.remove(conf, "astarte_data_updater_plant.amqp_producer_options.$option")

    if Enum.empty?(producer_options) do
      # FIXME: When adding astarte_rpc, fallback from astarte_rpc and create another transform
      Conform.Conf.get(conf, "astarte_data_updater_plant.amqp_consumer_options.$option")
    else
      # We take the actual configuration
      producer_options
    end
    |> Enum.map(fn {[_, _, key], value} -> {List.to_atom(key), value} end)
  end
end
