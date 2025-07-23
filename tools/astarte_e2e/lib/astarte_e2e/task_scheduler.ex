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

defmodule AstarteE2E.TaskScheduler do
  @moduledoc """
  Synchronization barrier used to terminate the application once all checks have been completed
  """

  use GenServer

  require Logger

  @timeout :timer.minutes(15)

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  @impl GenServer
  def init(_init_arg) do
    Process.flag(:trap_exit, true)
    device_id = Astarte.Core.Device.random_device_id()

    checks = [
      {AstarteE2E.VolatileTriggerRoundtrip.Executor, device_id},
      {AstarteE2E.DeviceDeletion, []},
      {AstarteE2E.AmqpDataTrigger, device_id}
    ]

    state =
      for {check, args} <- checks, into: %{} do
        {:ok, pid} = check.start_link(args)
        Logger.debug("Starting check #{inspect(check)} with pid #{inspect(pid)}")

        {pid, check}
      end

    {:ok, state, @timeout}
  end

  @impl GenServer
  def handle_info({:EXIT, pid, :normal}, state) do
    {check, new_state} = Map.pop(state, pid)

    if check != nil do
      Logger.debug("Check #{check.name()} terminated successfully")
    end

    cond do
      check == nil ->
        Logger.info("Received exit status from unknown pid #{inspect(pid)}, ignoring")
        {:noreply, new_state, @timeout}

      Enum.empty?(new_state) ->
        {:noreply, new_state, {:continue, :complete}}

      true ->
        {:noreply, new_state, @timeout}
    end
  end

  @impl GenServer
  def handle_info({:EXIT, pid, exit_status}, state) do
    Map.fetch(state, pid)
    |> case do
      :error ->
        Logger.info("Received exit status from unknown pid #{inspect(pid)}, ignoring")
        {:noreply, state, @timeout}

      {:ok, check} ->
        Logger.error("Check #{check.name()} terminated with #{inspect(exit_status)}, terminating")
        {:noreply, state, {:continue, :unalive}}
    end
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    missing_checks = Map.values(state) |> Enum.map(& &1.name())

    "Timeout waiting for checks to complete. Missing checks: #{inspect(missing_checks)}"
    |> Logger.error()

    {:noreply, state, {:continue, :unalive}}
  end

  @impl GenServer
  def handle_continue(:complete, state) do
    Logger.info("Terminating application successfully.", tag: "termination_success")

    System.halt(0)

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_continue(:unalive, state) do
    System.halt(1)
    {:stop, :error, state}
  end
end
