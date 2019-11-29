#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.Housekeeping do
  use Application

  alias Astarte.RPC.Protocol.Housekeeping, as: Protocol

  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Engine
  alias Astarte.Housekeeping.RPC.Handler

  def start(_type, _args) do
    :ok = Engine.init()

    children = [
      {Xandra.Cluster, nodes: Config.xandra_nodes(), name: :xandra},
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: Handler]}
    ]

    opts = [strategy: :rest_for_one, name: Astarte.Housekeeping.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
