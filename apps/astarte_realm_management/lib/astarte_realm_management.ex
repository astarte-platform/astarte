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

defmodule Astarte.RealmManagement do
  use Application
  require Logger

  alias Astarte.RPC.Protocol.RealmManagement, as: Protocol
  alias Astarte.RealmManagement.Config
  alias Astarte.RealmManagement.RPC.Handler
  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.RPC.Config, as: RPCConfig

  @app_version Mix.Project.config()[:version]

  def start(_type, _args) do
    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    _ = Logger.info("Starting application v#{@app_version}.", tag: "realm_management_app_start")

    Config.validate!()
    DataAccessConfig.validate!()
    RPCConfig.validate!()

    xandra_options = Config.xandra_options!()

    data_access_opts = [xandra_options: xandra_options]

    rm_xandra_opts = Keyword.put(xandra_options, :name, :xandra)

    children = [
      Astarte.RealmManagementWeb.Telemetry,
      {Xandra.Cluster, rm_xandra_opts},
      {Astarte.DataAccess, data_access_opts},
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: Handler]}
    ]

    opts = [strategy: :one_for_one, name: Astarte.RealmManagement.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
