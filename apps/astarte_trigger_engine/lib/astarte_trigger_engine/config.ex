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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.TriggerEngine.Config do
  @moduledoc """
  This module handles the configuration of TriggerEngine
  """

  @doc """
  Returns the AMQP events consumer connection options
  """
  def amqp_consumer_options do
    Application.get_env(:astarte_trigger_engine, :amqp_consumer_options, [])
  end

  @doc """
  Returns the events name of the exchange on which events are published
  """
  def events_exchange_name do
    Application.get_env(:astarte_trigger_engine, :amqp_events_exchange_name)
  end

  @doc """
  Returns the AMQP queue name created by the events consumer
  """
  def events_queue_name do
    Application.get_env(:astarte_trigger_engine, :amqp_events_queue_name)
  end

  @doc """
  Returns the routing_key used to bind to TriggerEngine specific events
  """
  def events_routing_key do
    Application.get_env(:astarte_trigger_engine, :amqp_events_routing_key)
  end
end
