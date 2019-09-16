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

defmodule Astarte.AppEngine.API.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

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

  @doc """
  Returns cassandra nodes formatted in the Xandra format
  """
  def xandra_nodes do
    Application.get_env(:cqerl, :cassandra_nodes, [{"localhost", "9042"}])
    |> Enum.map(fn {host, port} -> "#{host || "localhost"}:#{port || 9042}" end)
  end
end
