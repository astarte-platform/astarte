#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.Events.AMQPTriggers.VHostSupervisor do
  use DynamicSupervisor
  require Logger
  alias Astarte.Events.AMQPTriggers.Producer

  def start_link(init_arg \\ []) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("AMQPTriggers dynamic supervisor init.", tag: "amqp_triggers_sup_init")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def for_realm(realm_name, wait_start \\ false) do
    server_name = server_from_realm(realm_name)

    child = {Producer, [realm: realm_name, server: server_name, wait_start: wait_start]}

    case DynamicSupervisor.start_child(__MODULE__, child) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start child #{inspect(child)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def server_from_realm(realm_name) do
    {:via, Registry, {Astarte.Events.AMQPTriggers.Registry, {:amqp_producer, realm_name}}}
  end
end
