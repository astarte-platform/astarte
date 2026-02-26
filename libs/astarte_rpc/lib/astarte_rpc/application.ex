#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.RPC.Application do
  @moduledoc false

  use Application
  alias Astarte.RPC.Config
  alias Astarte.RPC.Server

  @impl true
  def start(_type, _args) do
    Config.validate!()

    children = [
      {Phoenix.PubSub, name: Server, pool_size: Config.pool_size!()},
      {Cluster.Supervisor, [Config.cluster_topologies!(), [name: Astarte.RPC.ClusterSupervisor]]}
    ]

    opts = [strategy: :one_for_one, name: Astarte.RPC.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
