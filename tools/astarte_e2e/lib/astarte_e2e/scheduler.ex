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
      |> to_ms()

    check_repetitions = Keyword.fetch!(opts, :check_repetitions)

    state = %{check_repetitions: check_repetitions, check_interval_ms: check_interval_ms}
    :timer.send_interval(check_interval_ms, :do_perform_check)

    {:ok, state}
  end

  @impl true
  def handle_info(:do_perform_check, %{check_repetitions: 0} = state) do
    Logger.info("Terminating application successfully.",
      tag: "astarte_e2e_scheduler_termination_success"
    )

    System.stop(0)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:do_perform_check, state) do
    case AstarteE2E.perform_check() do
      :ok ->
        handle_successful_job(state)

      {:error, :timeout} ->
        handle_timed_out_job(state)

      e ->
        Logger.warn("Unhandled condition #{inspect(e)}. Pretending everything is ok.")
        {:noreply, state}
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
          tag: "astarte_e2e_scheduler_request_timeout"
        )

        {:noreply, state}

      _ ->
        Logger.warn("Request timed out. This is a critical event. Terminating the application.",
          tag: "astarte_e2e_scheduler_critical_request_timeout"
        )

        System.stop(1)
        {:stop, :timeout, state}
    end
  end

  defp to_ms(seconds), do: seconds * 1_000

  defp via_tuple(realm, device_id) do
    {:via, Registry, {Registry.AstarteE2E, {:scheduler, realm, device_id}}}
  end
end
