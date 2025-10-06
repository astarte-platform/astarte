#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Application do
  @moduledoc false
  use Application

  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.Pairing.Config

  require Logger

  @app_version Mix.Project.config()[:version]
  @trigger_lifetime_ttl :timer.seconds(60)
  @trigger_cache_name Config.trigger_cache_name!()

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting application v#{@app_version}.", tag: "pairing_start")

    DataAccessConfig.validate!()
    Config.validate!()
    Config.init!()

    # Define workers and child supervisors to be supervised
    children = [
      Astarte.PairingWeb.Telemetry,
      {Astarte.Pairing.CredentialsSecret.Cache, []},
      Astarte.PairingWeb.Endpoint,
      {ConCache,
       [
         name: @trigger_cache_name,
         ttl_check_interval: :timer.seconds(1),
         global_ttl: @trigger_lifetime_ttl
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.Pairing.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Astarte.PairingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
