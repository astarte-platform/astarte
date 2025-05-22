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

    xandra_opts = Config.xandra_options!()

    data_access_opts = [xandra_options: xandra_opts]

    children = [
      Astarte.RealmManagementWeb.Telemetry,
      xandra_cluster_child_spec(xandra_opts: xandra_opts, name: :xandra),
      xandra_cluster_child_spec(xandra_opts: xandra_opts, name: :xandra_device_deletion),
      {Astarte.DataAccess, data_access_opts},
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: Handler]},
      {Task.Supervisor, name: Astarte.RealmManagement.DeviceRemoverSupervisor},
      Astarte.RealmManagement.DeviceRemoval.Scheduler
    ]

    opts = [strategy: :one_for_one, name: Astarte.RealmManagement.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def xandra_cluster_child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    xandra_opts =
      Keyword.fetch!(opts, :xandra_opts)
      |> Keyword.put(:name, name)
      # TODO move to string keys
      |> Keyword.put(:atom_keys, true)

    Supervisor.child_spec({Xandra.Cluster, xandra_opts}, id: name)
  end
end
