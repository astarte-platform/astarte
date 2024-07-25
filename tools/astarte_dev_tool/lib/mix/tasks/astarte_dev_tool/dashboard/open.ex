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

      $ mix dashboard.open -r test -k ../../test_private.pem

  ## Command line options
    * `-r` `--realm-name` - The name of the Astarte realm. Defaults to 'test'.

    * `-k` `--realm-private-key` - The path of the private key for the Astarte
      realm. Defaults to '../../test_private.pem'.

    * `-t` `--auth-token` - The auth token to use. If specified, it takes
      precedence over the --realm-private-key option.

    * `-u` `--dashboard-url` - The URL of the Astarte Dashboard. It defaults
      to 'http://dashboard.astarte.localhost'.
  """

  @impl true
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    {:ok, authenticated_url} = Dashboard.Open.exec(opts)

    Mix.Shell.IO.info("\nYou can access the Astarte Dashboard at:\n\n#{authenticated_url}")
  end
end
