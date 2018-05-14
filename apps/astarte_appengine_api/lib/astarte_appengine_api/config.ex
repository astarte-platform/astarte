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

defmodule Astarte.AppEngine.API.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  @doc """
  Returns the MQTT options
  """
  def mqtt_options do
    Application.get_env(:astarte_appengine_api, :mqtt_options, [])
  end

  @doc """
  Returns true if the authentication is disabled
  """
  def authentication_disabled? do
    Application.get_env(:astarte_appengine_api, :disable_authentication, false)
  end

  @doc """
  Returns the max query limit that is configured or nil if there's no limit
  """
  def max_results_limit do
    limit = Application.get_env(:astarte_appengine_api, :max_results_limit)

    if limit > 0 do
      limit
    else
      # If limit <= 0, no limit
      nil
    end
  end

  @doc """
  Returns the AMQP connection options for AMQP client consuming events for rooms.
  Defaults to []
  """
  def rooms_amqp_options do
    Application.get_env(:astarte_appengine_api, :rooms_amqp_client_options, [])
  end

  @doc """
  Returns the exchange name which Rooms AMQP events consumer binds to.
  """
  def events_exchange_name do
    Application.get_env(:astarte_appengine_api, :rooms_events_exchange_name, "astarte_events")
  end

  @doc """
  Returns the routing key used for Rooms AMQP events consumer. A constant for now.
  """
  def rooms_events_routing_key do
    "astarte_rooms"
  end

  @doc """
  Returns the queue name used for Rooms AMQP events consumer.
  """
  def rooms_events_queue_name do
    Application.get_env(:astarte_appengine_api, :rooms_events_queue_name, "astarte_rooms_events")
  end

  @doc """
  Returns the RPC client, defaulting to AMQP.Client. Used for Mox during testing.
  """
  def rpc_client do
    Application.get_env(:astarte_appengine_api, :rpc_client, Astarte.RPC.AMQP.Client)
  end
end
