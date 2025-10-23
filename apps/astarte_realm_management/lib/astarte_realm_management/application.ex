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

defmodule Astarte.RealmManagement.Application do
  use Application

  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.RealmManagement.Config

  require Logger

  @app_version Mix.Project.config()[:version]
  @trigger_lifetime_ttl :timer.seconds(60)
  @trigger_cache_id Config.trigger_cache!()

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting application v#{@app_version}.", tag: "realm_management_start")
    Astarte.RealmManagement.Config.validate!()
    DataAccessConfig.validate!()

    trigger_cache_opts = [
      name: @trigger_cache_id,
      ttl_check_interval: :timer.seconds(1),
      global_ttl: @trigger_lifetime_ttl
    ]

    children =
      [
        {Cluster.Supervisor,
         [Config.cluster_topologies!(), [name: Astarte.RealmManagement.ClusterSupervisor]]},
        Astarte.RealmManagementWeb.Telemetry,
        Astarte.RealmManagementWeb.Endpoint,
        {Task.Supervisor, name: Astarte.RealmManagement.DeviceRemoverSupervisor},
        Astarte.RealmManagement.DeviceRemoval.Scheduler,
        {ConCache, trigger_cache_opts}
      ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.RealmManagement.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
