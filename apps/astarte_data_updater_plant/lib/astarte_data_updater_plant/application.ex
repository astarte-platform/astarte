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

defmodule Astarte.DataUpdaterPlant.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl

  @app_version Mix.Project.config()[:version]

  def start(_type, _args) do
    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting application v#{@app_version}.", tag: "data_updater_plant_app_start")

    Config.validate!()
    DataAccessConfig.validate!()

    xandra_options = Config.xandra_options!()

    data_access_opts = [xandra_options: xandra_options]

    dup_xandra_opts = Keyword.put(xandra_options, :name, :xandra)

    children = [
      Astarte.DataUpdaterPlantWeb.Telemetry,
      {Xandra.Cluster, dup_xandra_opts},
      {Astarte.DataAccess, data_access_opts},
      Astarte.DataUpdaterPlant.DataPipelineSupervisor,
      {Mississippi.Consumer, mississippi_consumer_opts!()}
    ]

    opts = [strategy: :one_for_one, name: Astarte.DataUpdaterPlant.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp mississippi_consumer_opts!() do
    [
      amqp_consumer_options: [host: Config.amqp_consumer_host!()],
      mississippi_config: [
        queues: [
          events_exchange_name: Config.events_exchange_name!(),
          prefix: Config.data_queue_prefix!(),
          range_start: Config.data_queue_range_start!(),
          range_end: Config.data_queue_range_end!(),
          total_count: Config.data_queue_total_count!()
        ],
        message_handler: Impl
      ]
    ]
  end
end
