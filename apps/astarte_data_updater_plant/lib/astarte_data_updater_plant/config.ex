#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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
#

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
    Application.get_env(
      :astarte_data_updater_plant,
      :amqp_producer_options,
      amqp_consumer_options()
    )
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

  @doc """
  Returns the RPC client, defaulting to AMQP.Client. Used for Mox during testing.
  """
  def rpc_client do
    Application.get_env(:astarte_data_updater_plant, :rpc_client, Astarte.RPC.AMQP.Client)
  end
end
