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

defmodule Mix.Tasks.AstarteDevTool.Dashboard.Open do
  use Mix.Task
  alias AstarteDevTool.Commands.Dashboard
  alias AstarteDevTool.Utilities.Path
  alias AstarteDevTool.Utilities.Auth

  @shortdoc "Open an authenticate Astarte Dashboard session"

  @aliases [
    r: :realm_name,
    k: :realm_private_key,
    t: :auth_token,
    u: :dashboard_url
  ]

  @switches [
    realm_name: :string,
    realm_private_key: :string,
    auth_token: :string,
    dashboard_url: :string
  ]

  @moduledoc """
  Open an authenticate Astarte Dashboard session.

  ## Examples

      $ mix astarte_dev_tool.dashboard.open -r test -k ../../test_private.pem

  ## Command line options
    * `-r` `--realm-name` - (required) The name of the Astarte realm.

    * `-u` `--dashboard-url` - (required) The URL of the Astarte Dashboard

    * `-k` `--realm-private-key` - (required if --auth-token is not provided) The path of the private key for the Astarte
      realm.

    * `-t` `--auth-token` - (required if --realm-private-key is not provided) The auth token to use. If specified, it takes
      precedence over the --realm-private-key option.
  """

  @impl true
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    unless Keyword.has_key?(opts, :dashboard_url),
      do: Mix.raise("The --dashboard-url argument is required")

    unless Keyword.has_key?(opts, :realm_name),
      do: Mix.raise("The --realm_name argument is required")

    unless Keyword.has_key?(opts, :realm_private_key) or Keyword.has_key?(opts, :auth_token),
      do: Mix.raise("One of --realm-private-key and --auth_token must be provided")

    if log_level = opts[:log_level],
      do: Logger.configure(level: String.to_existing_atom(log_level))

    auth_token =
      case Keyword.has_key?(opts, :auth_token) do
        true ->
          opts[:auth_token]

        false ->
          private_key_path = opts[:realm_private_key]

          with {:ok, abs_path} <- Path.path_from(private_key_path),
               {:ok, private_key} <- File.read(abs_path),
               {:ok, auth_token} <- Auth.gen_auth_token(private_key) do
            auth_token
          else
            {:error, output} ->
              Mix.raise("Failed auth_token generation. Output: #{output}")
          end
      end

    dashboard_url = opts[:dashboard_url]
    realm_name = opts[:realm_name]

    case Dashboard.Open.exec(realm_name, dashboard_url, auth_token) do
      {:ok, authenticated_url} ->
        Mix.shell().info("Astarte Dashboard started at: #{authenticated_url}")
        :ok

      {:error, output} ->
        Mix.raise("Failed to start Astarte's Dashboard. Output: #{output}")
    end
  end
end
