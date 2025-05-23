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
  alias AstarteE2E.Utils
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

    state = %{check_repetitions: check_repetitions, check_interval_ms: check_interval_ms}
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
    return_val =
      case AstarteE2E.perform_check() do
        :ok ->
          handle_successful_job(state)

        {:error, :timeout} ->
          handle_timed_out_job(state)

        {:error, :not_connected} ->
          {:noreply, state}

        e ->
          Logger.warning("Unhandled condition #{inspect(e)}. Pretending everything is ok.")
          {:noreply, state}
      end

    Process.send_after(self(), :do_perform_check, state.check_interval_ms)
    return_val
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
        Logger.warning("Request timed out. This event affects the service metrics.",
          tag: "request_timeout"
        )

        {:noreply, state}

      _ ->
        Logger.warning(
          "Request timed out. This is a critical event. Terminating the application.",
          tag: "critical_request_timeout"
        )

        System.stop(1)
        {:stop, :timeout, state}
    end
  end

  defp via_tuple(realm, device_id) do
    {:via, Registry, {Registry.AstarteE2E, {:scheduler, realm, device_id}}}
  end
end
