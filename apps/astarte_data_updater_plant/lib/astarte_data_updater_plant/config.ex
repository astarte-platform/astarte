defmodule Astarte.DataUpdaterPlant.Config do
  @moduledoc """
  This module handles the configuration of DataUpdaterPlant
  """

  @doc """
  Returns the AMQP data consumer connection options
  """
  def amqp_consumer_options do
    Application.get_env(:astarte_data_updater_plant, :amqp_consumer_options, [])
  end

  @doc """
  Returns the AMQP trigger producer connection options
  """
  def amqp_producer_options do
    Application.get_env(:astarte_data_updater_plant, :amqp_producer_options, amqp_consumer_options())
  end

  @doc """
  Returns the events exchange name used by the AMQP producer
  """
  def events_exchange_name do
    Application.get_env(:astarte_data_updater_plant, :amqp_events_exchange_name)
  end

  @doc """
  Returns the AMQP queue name from which DUP consumes
  """
  def queue_name do
    Application.get_env(:astarte_data_updater_plant, :queue_name)
  end

  @doc """
  Returns the AMQP consumer prefetch count for the consumer. Defaults to 300.
  """
  def amqp_consumer_prefetch_count do
    Application.get_env(:astarte_data_updater_plant, :amqp_consumer_prefetch_count, 300)
  end
end
