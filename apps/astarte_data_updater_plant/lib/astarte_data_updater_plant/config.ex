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
  Returns the AMQP queue name from which DUP consumes
  """
  def queue_name do
    Application.get_env(:astarte_data_updater_plant, :queue_name)
  end
end
