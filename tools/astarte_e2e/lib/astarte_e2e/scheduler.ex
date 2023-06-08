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

defmodule AstarteE2E.Scheduler do
  alias AstarteE2E.{Client, Utils}
  require Logger

  use GenServer, restart: :transient

  def start_link(opts) do
    realm = Keyword.fetch!(opts, :realm)
    device_id = Keyword.fetch!(opts, :device_id)

    GenServer.start_link(__MODULE__, opts, name: via_tuple(realm, device_id))
  end

  @impl true
  def init(opts) do
    check_interval_ms =
      Keyword.fetch!(opts, :check_interval_s)
      |> Utils.to_ms()

    check_repetitions = Keyword.fetch!(opts, :check_repetitions)

    realm = Keyword.fetch(opts, :realm)
    device_id = Keyword.fetch!(opts, :device_id)
    timeout = Keyword.fetch!(opts, :timeout)

    state = %{
      check_repetitions: check_repetitions,
      check_interval_ms: check_interval_ms,
      realm: realm,
      device_id: device_id,
      timeout: timeout
    }

    Process.send_after(self(), :do_perform_check, check_interval_ms)

    {:ok, state}
  end

  @impl true
  def handle_info(:do_perform_check, %{check_repetitions: 0} = state) do
    Logger.info("Terminating application successfully.",
      tag: "termination_success"
    )

    System.stop(0)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:do_perform_check, state) do
    Process.send_after(self(), :do_perform_check, state.check_interval_ms)

    check_result = AstarteE2E.perform_check()

    updated_state = update_in(state.timeout, &maybe_timeout(&1, state, check_result))

    case check_result do
      :ok ->
        handle_successful_job(updated_state)

      {:error, :timeout} ->
        handle_timed_out_job(updated_state)

      {:error, :not_connected} ->
        {:noreply, updated_state}

      e ->
        Logger.warn("Unhandled condition #{inspect(e)}. Pretending everything is ok.")
        {:noreply, updated_state}
    end
  end

  defp handle_successful_job(state) do
    case state.check_repetitions do
      :infinity ->
        {:noreply, state}

      _ ->
        updated_count = state.check_repetitions - 1
        {:noreply, %{state | check_repetitions: updated_count}}
    end
  end

  defp handle_timed_out_job(state) do
    case state.check_repetitions do
      :infinity ->
        Logger.warn("Request timed out. This event affects the service metrics.",
          tag: "request_timeout"
        )

        {:noreply, state}

      _ ->
        Logger.warn("Request timed out. This is a critical event. Terminating the application.",
          tag: "critical_request_timeout"
        )

        System.stop(1)
        {:stop, :timeout, state}
    end
  end

  defp maybe_timeout(timeout, state, check_result) do
    cond do
      timeout == :inactive or check_result == :ok -> :inactive
      timeout == {:active, 1} -> call_timeout_and_set_inactive(state)
      {:active, x} = timeout -> {:active, x - 1}
    end
  end

  defp call_timeout_and_set_inactive(state) do
    %{realm: {:ok, realm}, device_id: device_id} = state
    Client.notify_startup_timeout(realm, device_id)
    :inactive
  end

  defp via_tuple(realm, device_id) do
    {:via, Registry, {Registry.AstarteE2E, {:scheduler, realm, device_id}}}
  end
end
