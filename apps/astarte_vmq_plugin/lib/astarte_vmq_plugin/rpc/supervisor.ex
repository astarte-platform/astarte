#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.VMQ.Plugin.RPC.Supervisor do
  @moduledoc """
  Supervisor of the RPC server.
  """

  use Horde.DynamicSupervisor

  require Logger

  def start_link(init_arg, opts \\ []) do
    opts = [{:name, __MODULE__} | opts]

    with {:ok, supervisor_wrapper_pid} <-
           Horde.DynamicSupervisor.start_link(__MODULE__, init_arg, opts) do
      initialize_horde_supervisor(supervisor_wrapper_pid)
    end
  end

  @impl Horde.DynamicSupervisor
  def init(init_arg) do
    [
      strategy: :one_for_one,
      members: :auto,
      distribution_strategy: Horde.UniformDistribution,
      restart: :always
    ]
    |> Keyword.merge(init_arg)
    |> Horde.DynamicSupervisor.init()
  end

  defp initialize_horde_supervisor(supervisor_wrapper_pid) do
    with {:ok, supervisor_pid} <- supervisor_pid(supervisor_wrapper_pid),
         :ok <- start_rpc_server(supervisor_pid) do
      {:ok, supervisor_wrapper_pid}
    else
      error ->
        # the initialization completed with error, stop the supervisor wrapper
        :ok = GenServer.stop(supervisor_wrapper_pid, :invalid_init)
        error
    end
  end

  defp start_rpc_server(supervisor) do
    Horde.DynamicSupervisor.start_child(supervisor, Astarte.VMQ.Plugin.RPC.Server)
    |> case do
      {:ok, _pid} = ok ->
        "RPC server: started successfully: #{inspect(ok)}"
        |> Logger.debug(tag: "rpc_started")

        :ok

      {:ok, _pid, _info} = ok ->
        "RPC server: started successfully: #{inspect(ok)}"
        |> Logger.debug(tag: "rpc_started")

        :ok

      {:error, {:already_started, _pid}} = ok ->
        "RPC server: already running: #{inspect(ok)}"
        |> Logger.debug(tag: "rpc_started")

        :ok

      :ignore ->
        "RPC server: start ignored"
        |> Logger.warning(tag: "rpc_not_started")

        {:error, :rpc_start_ignored}

      {:error, reason} ->
        "RPC server: error during startup: #{inspect(reason)}"
        |> Logger.warning(tag: "rpc_not_started")

        {:error, :rpc_start_error}
    end
  end

  defp supervisor_pid(supervisor_wrapper_pid) do
    supervisor_wrapper_pid
    |> Horde.DynamicSupervisor.which_children()
    |> Enum.find_value(fn {id, child, _type, _modules} ->
      id == Horde.DynamicSupervisorImpl && child
    end)
    |> case do
      nil -> {:error, :supervisor_impl_not_found}
      pid when is_pid(pid) -> {:ok, pid}
      child -> {:error, {:supervisor_impl_not_ready, child}}
    end
  end
end
