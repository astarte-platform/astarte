#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 Seco Mind Srl
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

defmodule Astarte.AppEngine.API.Application do
  use Application
  require Logger

  @app_version Mix.Project.config()[:version]

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    alias Astarte.AppEngine.API.Config
    alias Astarte.DataAccess.Config, as: DataAccessConfig

    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting application v#{@app_version}.", tag: "appengine_api_start")

    DataAccessConfig.validate!()
    Config.validate!()

    # Define workers and child supervisors to be supervised
    children = [
      {Cluster.Supervisor,
       [Config.cluster_topologies!(), [name: Astarte.AppEngine.API.ClusterSupervisor]]},
      {Horde.Registry, [keys: :unique, name: Registry.DataUpdaterRPC, members: :auto]},
      {Horde.Registry, [keys: :unique, name: Registry.VMQPluginRPC, members: :auto]},
      Astarte.AppEngine.APIWeb.Telemetry,
      {Phoenix.PubSub, name: Astarte.AppEngine.API.PubSub},
      Astarte.AppEngine.API.Rooms.MasterSupervisor,
      Astarte.AppEngine.API.Rooms.AMQPClient,
      Astarte.AppEngine.APIWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.AppEngine.API.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Astarte.AppEngine.APIWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
