# Copyright 2017-2021 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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
  alias Astarte.Housekeeping.Config
  alias Astarte.RPC.Config, as: RPCConfig
  alias Astarte.DataAccess.Config, as: DataAccessConfig

  use Application

  require Logger

  @app_version Mix.Project.config()[:version]

  def start(_type, _args) do
    Config.validate!()
    RPCConfig.validate!()
    DataAccessConfig.validate!()

    children = [
      Astarte.HousekeepingWeb.Telemetry,
      Astarte.Housekeeping.BackendSupervisor
    ]

    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting application v#{@app_version}.", tag: "housekeeping_app_start")

    opts = [strategy: :one_for_one, name: Astarte.Housekeeping.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
