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

  @doc """
  Returns the module used to consume events, used for tests with Mox
  """
  def events_consumer do
    alias Astarte.TriggerEngine.EventsConsumer
    Application.get_env(:astarte_trigger_engine, :events_consumer, EventsConsumer)
  end
end
