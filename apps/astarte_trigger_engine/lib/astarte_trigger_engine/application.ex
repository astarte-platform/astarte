#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.TriggerEngine.Application do
  @moduledoc false

  use Application
  require Logger

  alias Astarte.TriggerEngine.Config
  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.TriggerEngine.DeliverySupervisor

  @app_version Mix.Project.config()[:version]

  def start(_type, _args) do
    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting application v#{@app_version}.", tag: "trigger_engine_app_start")

    Config.validate!()
    DataAccessConfig.validate!()

    xandra_options = Config.xandra_options!()
    xandra_cluster_options = Keyword.put(xandra_options, :name, :xandra)
    data_access_opts = [xandra_options: xandra_options]

    children = [
      Astarte.TriggerEngineWeb.Telemetry,
      {Xandra.Cluster, xandra_cluster_options},
      {Astarte.TriggerEngine.Repo, xandra_options},
      {Astarte.DataAccess, data_access_opts},
      DeliverySupervisor
    ]

    opts = [strategy: :one_for_one, name: Astarte.TriggerEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
