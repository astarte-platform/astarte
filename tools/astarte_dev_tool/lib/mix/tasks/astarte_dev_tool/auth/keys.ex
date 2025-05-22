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

defmodule Mix.Tasks.AstarteDevTool.Auth.Keys do
  use Mix.Task
  alias AstarteDevTool.Commands.Auth.Keys

  @shortdoc "Astarte keys generation"

  @aliases []

  @switches [
    log_level: :string
  ]

  @moduledoc """
  Astarte auth key generation.
  If no `arg` is provided, a private key is released
  If a private key is provided via `arg`, the linked public key is released.

  ## Examples

      $ mix astarte_dev_tool.auth.key
      $ mix astarte_dev_tool.auth.key "-----BEGIN EC PRIVATE KEY-----Base64-----END EC PRIVATE KEY-----"
      $ mix astarte_dev_tool.auth.key "$(mix astarte_dev_tool.auth.key)"

  ## Command line options
    * `--log-level` - the level to set for `Logger`. This task
      does not start your application, so whatever level you have configured in
      your config files will not be used. If this is not provided, no level
      will be set, so that if you set it yourself before calling this task
      then this won't interfere. Can be any of the `t:Logger.level/0` levels
  """

  @impl true
  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    if Enum.count(args) > 1,
      do: Mix.raise("Only one optional argument - the private key - is allowed")

    if log_level = opts[:log_level],
      do: Logger.configure(level: String.to_existing_atom(log_level))

    case Keys.exec(Enum.at(args, 0)) do
      {:ok, key} ->
        # Result to stdout
        IO.puts(key)
        {:ok, key}

      {:error, reason} ->
        Mix.raise("Error generating key: #{reason}")
    end
  end
end
