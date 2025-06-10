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

defmodule Astarte.Housekeeping.API.Application do
  use Application
  require Logger

  alias Astarte.Housekeeping.API.Config
  alias Astarte.RPC.Config, as: RPCConfig
  alias Astarte.DataAccess.Config, as: DataAccessConfig

  @app_version Mix.Project.config()[:version]

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting application v#{@app_version}.", tag: "housekeeping_api_start")

    Config.validate!()
    RPCConfig.validate!()
    DataAccessConfig.validate!()
    Config.validate_jwt_public_key_pem!()

    # Define workers and child supervisors to be supervised
    children = [
      Astarte.Housekeeping.APIWeb.Telemetry,
      Astarte.Housekeeping.APIWeb.Endpoint,
      Astarte.Housekeeping.API.BackendSupervisor
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.Housekeeping.API.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
