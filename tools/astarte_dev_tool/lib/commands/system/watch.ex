#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule AstarteDevTool.Commands.System.Watch do
  @moduledoc false
  require Logger
  alias AstarteDevTool.Constants.System, as: Constants
  alias AstarteDevTool.Utilities.Process, as: AstarteProcess

  def exec(path) do
    with :ok <- check_and_kill_process(path),
         task <- Task.async(fn -> execute_process(path) end),
         :ok <- listen_for_input(),
         nil <- Task.shutdown(task, :brutal_kill),
         :ok <- check_and_kill_process(path) do
      :ok
    end
  end

  defp execute_process(path) do
    case System.cmd(
           Constants.command(),
           Constants.command_watch_args(),
           Constants.base_opts() ++ [cd: path]
         ) do
      {_result, 0} -> :ok
      {:error, reason} -> {:error, "Cannot run system watching: #{reason}"}
      {result, exit_code} -> {:error, "Cannot exec system.watch: #{result}, #{exit_code}"}
    end
  end

  defp listen_for_input() do
    IO.puts("Press ENTER to stop watching.")
    IO.gets("")
    IO.puts("Stopping...")
    :ok
  end

  defp check_and_kill_process(path) do
    case AstarteProcess.check_process(Constants.command(), Constants.command_watch_args(), path) do
      {:ok, pid} when not is_nil(pid) -> kill_zombie_process(pid)
      _ -> :ok
    end
  end

  defp kill_zombie_process(pid) do
    # Kill zombie watching process
    # The function is required to terminate the previous zombie
    # process if closed by closing the mix shell
    # TODO: to be implemented differently with https://github.com/alco/porcelain

    case System.cmd("kill", [pid]) do
      {_result, 0} -> Logger.info("Watching zombie process ##{pid} killed")
      _ -> {:error, "Cannot kill zombie process"}
    end
  end
end
