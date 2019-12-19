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

defmodule Astarte.DataUpdaterPlant.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Astarte.DataUpdaterPlant.AMQPDataConsumer
  alias Astarte.DataUpdaterPlant.AMQPEventsProducer
  alias Astarte.DataUpdaterPlant.RPC.Handler

  alias Astarte.RPC.Protocol.DataUpdaterPlant, as: Protocol

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Registry, [keys: :unique, name: Registry.MessageTracker]},
      {Registry, [keys: :unique, name: Registry.DataUpdater]},
      AMQPDataConsumer,
      AMQPEventsProducer,
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: Handler]},
      Astarte.RPC.AMQP.Client
    ]

    opts = [strategy: :rest_for_one, name: Astarte.DataUpdaterPlant.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
