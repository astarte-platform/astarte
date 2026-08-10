#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Astarte.VMQ.Plugin.Config

  require Logger

  @app_version Mix.Project.config()[:version]

  def start(_type, _args) do
    Logger.info("Starting Astarte plugin v#{@app_version}.", tag: "vmq_plugin_app_start")

    Config.init()

    # List all child processes to be supervised
    children = [
      {Mississippi.Producer, Config.mississippi_opts!()},
      {Registry, keys: :unique, name: AstarteVMQPluginConnectionSynchronizer.Registry},
      Astarte.VMQ.Plugin.Connection.Synchronizer.Supervisor,
      {Astarte.VMQ.Plugin.Publisher, [Config.registry_mfa()]},
      {Horde.Registry, [name: Registry.VMQPluginRPC, keys: :unique, members: :auto]},
      Astarte.VMQ.Plugin.RPC.Supervisor,
      {Xandra.Cluster, Config.xandra_options!()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.VMQ.Plugin.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
