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
  alias Astarte.PairingWeb.Endpoint

  require Logger

  @app_version Mix.Project.config()[:version]

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
    children =
      [
        Astarte.PairingWeb.Telemetry,
        maybe_child({Astarte.Pairing.CredentialsSecret.Cache, []}),
        maybe_child({Astarte.RPC.Triggers.Client, types: [:DEVICE_REGISTERED]}),
        Astarte.PairingWeb.Endpoint,
        maybe_child({Astarte.Events.AMQPEvents.Supervisor, []}),
        maybe_child({Astarte.Events.AMQPTriggers.Supervisor, []}),
        maybe_child({Astarte.Events.Triggers.Supervisor, []})
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.Pairing.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_child({Astarte.RPC.Triggers.Client, _opts} = spec) do
    if GenServer.whereis(Astarte.RPC.Triggers.Client) ||
         GenServer.whereis(:astarte_rpc_triggers_client) do
      nil
    else
      spec
    end
  end

  defp maybe_child({Astarte.Events.AMQPEvents.Supervisor, _} = spec) do
    if GenServer.whereis(Astarte.Events.AMQPEvents.Producer) do
      nil
    else
      spec
    end
  end

  defp maybe_child({Astarte.Events.AMQPTriggers.Supervisor, _} = spec) do
    if GenServer.whereis(Astarte.Events.AMQPTriggers.Registry) do
      nil
    else
      spec
    end
  end

  defp maybe_child({Astarte.Events.Triggers.Supervisor, _} = spec) do
    if GenServer.whereis(:event_targets) do
      nil
    else
      spec
    end
  end

  defp maybe_child({_module, opts} = spec) when is_list(opts) do
    name = Keyword.get(opts, :name)

    if name && GenServer.whereis(name) do
      nil
    else
      spec
    end
  end

  defp maybe_child({module, _opts} = spec) when is_atom(module) do
    if GenServer.whereis(module) do
      nil
    else
      spec
    end
  end

  defp maybe_child(module) when is_atom(module) do
    if GenServer.whereis(module) do
      nil
    else
      module
    end
  end

  defp maybe_child(spec), do: spec
end
