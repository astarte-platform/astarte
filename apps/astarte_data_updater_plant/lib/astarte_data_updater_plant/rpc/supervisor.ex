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

defmodule Astarte.DataUpdaterPlant.RPC.Supervisor do
  @moduledoc """
  Supervisor of the RPC server module.
  """

  use Horde.DynamicSupervisor

  require Logger

  def start_link(init_arg, opts \\ []) do
    opts = [{:name, __MODULE__} | opts]

    with {:ok, pid} <- Horde.DynamicSupervisor.start_link(__MODULE__, init_arg, opts) do
      Horde.DynamicSupervisor.start_child(pid, Astarte.DataUpdaterPlant.RPC.Server)
      |> case do
        :ignore ->
          "RPC server: start ignored"
          |> Logger.warning(tag: "rpc_not_started")

        {:error, reason} ->
          "RPC server: error during startup: #{inspect(reason)}"
          |> Logger.warning(tag: "rpc_not_started")

        ok ->
          ok
      end

      {:ok, pid}
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
end
