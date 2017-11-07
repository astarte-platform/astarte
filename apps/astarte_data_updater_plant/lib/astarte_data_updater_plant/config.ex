defmodule Astarte.DataUpdaterPlant.Config do
  @moduledoc """
  This module handles the configuration of DataUpdaterPlant
  """

  @doc """
  Returns the AMQP queue name from which DUP consumes
  """
  def queue_name do
    Application.get_env(:astarte_data_updater_plant, :queue_name)
  end
end
