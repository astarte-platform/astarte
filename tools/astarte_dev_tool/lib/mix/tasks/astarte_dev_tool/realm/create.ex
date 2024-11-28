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

defmodule Mix.Tasks.AstarteDevTool.Realm.Create do
  use Mix.Task
  alias Astarte.Core.Realm
  alias AstarteDevTool.Utilities.Node
  alias AstarteDevTool.Commands.Realm.Create
  alias AstarteDevTool.Utilities.Path

  @shortdoc "Create realm/s into the running Astarte"

  @aliases [
    p: :path,
    n: :node
  ]

  @switches [
    path: :string,
    node: :keep,
    log_level: :string
  ]

  @moduledoc """
  Create realm into the running Astarte platform.

  ## Examples

      $ mix astarte_dev_tool.realm.create -n localhost:12345 realm1
      $ mix astarte_dev_tool.realm.create -n localhost:12345 -n cassandra:54321 realm1

  ## Command line options
    * `-p` `--path` - (required) working Astarte project directory

    * `-n` `--node` - (at least one is required) Cassandra/Scylla cluster node.
      Every node has format **host/ip:port**

    * `--log-level` - the level to set for `Logger`. This task
      does not start your application, so whatever level you have configured in
      your config files will not be used. If this is not provided, no level
      will be set, so that if you set it yourself before calling this task
      then this won't interfere. Can be any of the `t:Logger.level/0` levels
  """

  @impl true
  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    unless Keyword.has_key?(opts, :path), do: Mix.raise("The --path argument is required")

    unless Keyword.has_key?(opts, :node),
      do: Mix.raise("At least one --node argument is required")

    unless Enum.count(args) === 1,
      do: Mix.raise("The command required one argument - the Realm name")

    realm_name = Enum.at(args, 0)

    unless Realm.valid_name?(realm_name),
      do: Mix.raise("Invalid Realm name provided")

    nodes =
      case(opts |> Keyword.get_values(:node) |> Node.parse_nodes()) do
        {:ok, nodes} -> nodes
        {:error, _} -> Mix.raise("--node argument must be in <host/ip>:<port> format")
      end

    if log_level = opts[:log_level],
      do: Logger.configure(level: String.to_existing_atom(log_level))

    with path <- opts[:path],
         {:ok, abs_path} <- Path.directory_path_from(path),
         :ok <- Mix.Tasks.AstarteDevTool.System.Check.run(["-p", abs_path]),
         :ok <- Create.exec(nodes, realm_name) do
      Mix.shell().info("Realms created successfully.")
      :ok
    else
      {:error, output} ->
        Mix.raise("Failed to create Astarte's realms. Output: #{output}")
    end
  end
end
