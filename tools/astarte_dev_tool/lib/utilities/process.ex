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

defmodule AstarteDevTool.Utilities.Process do
  alias AstarteDevTool.Constants.System, as: SystemConstants

  def version_ref,
    do: %Version{
      major: 27,
      minor: 2,
      patch: 2
    }

  def check_valid_version() do
    with {version, 0} <-
           System.cmd(SystemConstants.command(), SystemConstants.command_version_args()),
         {:ok, version} <- clean_version(version),
         {:ok, version} <- Version.parse(version) do
      result =
        case Version.compare(version, version_ref()) do
          :lt -> false
          _ -> true
        end

      {:ok, result}
    else
      _ ->
        {:error, :version_badformatted}
    end
  end

  defp clean_version(version), do: {:ok, version |> String.trim() |> String.trim("'")}

  def check_process(command, args, path) when is_list(args) do
    command = "#{command} #{Enum.join(args, " ")}"
    check_process(command, path)
  end

  def check_process(command, path) when is_bitstring(command) and is_bitstring(path) do
    with {:ok, pids} <- find_pids_by_command(command),
         {:ok, pid} <- find_pid_by_path(pids, path) do
      {:ok, pid}
    end
  end

  defp find_pids_by_command(command) do
    case System.cmd("pgrep", ["-f", command]) do
      {pids_str, 0} -> {:ok, String.trim(pids_str) |> String.split("\n")}
      _ -> {:ok, []}
    end
  end

  defp find_pid_by_path([], _path), do: {:ok, nil}

  defp find_pid_by_path([pid | rest], path) do
    if process_matches_path?(pid, path), do: {:ok, pid}, else: find_pid_by_path(rest, path)
  end

  def process_matches_path?(pid, path) do
    {lsof_output, 0} = System.cmd("lsof", ["-p", to_string(pid), "-Fn"])

    cwd =
      lsof_output
      |> String.split("\n")
      |> Enum.find(fn line -> String.starts_with?(line, "n") end)
      |> case do
        "n" <> cwd -> String.trim(cwd)
        _ -> nil
      end

    cwd == path
  end
end
