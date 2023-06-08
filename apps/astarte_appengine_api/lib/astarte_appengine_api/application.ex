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

defmodule Astarte.AppEngine.API.Application do
  use Application
  require Logger

  @app_version Mix.Project.config()[:version]

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    alias Astarte.AppEngine.API.Config
    alias Astarte.DataAccess.Config, as: DataAccessConfig
    alias Astarte.RPC.Config, as: RPCConfig

    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting application v#{@app_version}.", tag: "appengine_api_start")

    DataAccessConfig.validate!()
    RPCConfig.validate!()
    Config.validate!()

    xandra_options = Config.xandra_options!()

    data_access_opts = [xandra_options: xandra_options]

    ae_xandra_opts = Keyword.put(xandra_options, :name, :xandra)

    # Define workers and child supervisors to be supervised
    children = [
      Astarte.AppEngine.APIWeb.Telemetry,
      {Phoenix.PubSub, name: Astarte.AppEngine.API.PubSub},
      Astarte.RPC.AMQP.Client,
      Astarte.AppEngine.API.Rooms.MasterSupervisor,
      Astarte.AppEngine.API.Rooms.AMQPClient,
      Astarte.AppEngine.APIWeb.Endpoint,
      {Xandra.Cluster, ae_xandra_opts},
      {Astarte.DataAccess, data_access_opts}
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
