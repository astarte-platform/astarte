#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E.Application do
  use Application

  alias AstarteE2E.Config
  alias AstarteE2E.Realm
  alias AstarteE2E.ServiceNotifier

  require Logger

  @trigger_engine_consumer_tracker_cycle_duration :timer.seconds(30)

  @impl true
  def start(_type, _args) do
    Logger.info("Starting AstarteE2E application.", tag: "application_start")

    with :ok <- Config.validate(),
         :ok <- Realm.create_realm!() do
      # ensure trigger engine started the consumer for the new realm
      :timer.sleep(@trigger_engine_consumer_tracker_cycle_duration)

      children = [
        {Registry, keys: :unique, name: Registry.AstarteE2E},
        AstarteE2EWeb.Telemetry,
        {ServiceNotifier, Config.notifier_opts()},
        AstarteE2E.TaskScheduler
      ]

      opts = [strategy: :one_for_one, name: __MODULE__]

      Supervisor.start_link(children, opts)
    else
      {:error, reason} ->
        Logger.warning(
          "Configuration incomplete. Unable to start process with reason: #{reason}."
        )

        {:shutdown, reason}
    end
  end
end
