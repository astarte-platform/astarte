# Copyright 2017-2021 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

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

defmodule Astarte.Pairing do
  @moduledoc false

  use Application
  require Logger

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.RPC.Handler

  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.RPC.Protocol.Pairing, as: Protocol

  @app_version Mix.Project.config()[:version]

  def start(_type, _args) do
    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    Logger.info("Starting application v#{@app_version}.", tag: "pairing_app_start")

    DataAccessConfig.validate!()
    Config.validate!()
    Config.init!()

    xandra_options =
      Config.xandra_options!()
      |> Keyword.put(:name, :xandra)

    children = [
      Astarte.PairingWeb.Telemetry,
      {Xandra.Cluster, xandra_options},
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: Handler]},
      {Astarte.Pairing.CredentialsSecret.Cache, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
