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

defmodule Mix.Tasks.AstarteDevTool.System.Check do
  use Mix.Task
  alias AstarteDevTool.Commands.System.Check
  alias AstarteDevTool.Utilities.Path

  @shortdoc "Check if the current Astarte is up & running"

  @aliases [
    p: :path
  ]

  @switches [
    path: :string,
    log_level: :string
  ]

  @moduledoc """
  Check if the current Astarte is up & running.

  ## Examples

      $ mix astarte_dev_tool.system.check -p /absolute/path/astarte
      $ mix astarte_dev_tool.system.check -p ../../relative/to/astarte

  ## Command line options
    * `-p` `--path` - (required) working Astarte project directory

    * `--log-level` - the level to set for `Logger`. This task
      does not start your application, so whatever level you have configured in
      your config files will not be used. If this is not provided, no level
      will be set, so that if you set it yourself before calling this task
      then this won't interfere. Can be any of the `t:Logger.level/0` levels
  """

  @impl true
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    unless Keyword.has_key?(opts, :path), do: Mix.raise("The --path argument is required")

    if log_level = opts[:log_level],
      do: Logger.configure(level: String.to_existing_atom(log_level))

    with path <- opts[:path],
         {:ok, abs_path} <- Path.directory_path_from(path) do
      case Check.exec(abs_path) do
        :ok ->
          Mix.shell().info("All Astarte's services are up & ready")
          :ok

        {:error, list} = data ->
          Mix.raise("Some Astarte's services do not seem to be working: #{list}")
          data
      end
    else
      {:error, output} ->
        Mix.raise("Failed to check Astarte's system. Output: #{output}")
    end
  end
end
