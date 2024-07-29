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

defmodule AstarteDevTool.Commands.Dashboard.Open do
  @moduledoc false

  require Logger

  def exec(opts) do
    dashboard_url = Keyword.get(opts, :dashboard_url, "http://dashboard.astarte.localhost/")
    realm_name = Keyword.get(opts, :realm_name, "test")
    private_key_path = Keyword.get(opts, :realm_private_key, "../../test_private.pem")

    {:ok, auth_token} =
      with :error <- Keyword.fetch(opts, :auth_token) do
        private_key = File.read!(private_key_path)

        Astarte.Client.Credentials.dashboard_credentials()
        |> Astarte.Client.Credentials.to_jwt(private_key)
      end

    authenticated_url =
      dashboard_url
      |> URI.new!()
      |> URI.append_path("/auth")
      |> URI.append_query("realm=" <> realm_name)
      |> URI.to_string()
      |> Kernel.<>("#access_token=" <> auth_token)
      |> URI.encode()

    _ = open_in_browser(authenticated_url)

    {:ok, authenticated_url}
  end

  defp open_in_browser(url) do
    win_cmd_args = ["/c", "start", String.replace(url, "&", "^&")]

    cmd_args =
      case :os.type() do
        {:win32, _} ->
          {"cmd", win_cmd_args}

        {:unix, :darwin} ->
          {"open", [url]}

        {:unix, _} ->
          cond do
            System.find_executable("xdg-open") -> {"xdg-open", [url]}
            # When inside WSL
            System.find_executable("cmd.exe") -> {"cmd.exe", win_cmd_args}
            true -> nil
          end
      end

    case cmd_args do
      {cmd, args} ->
        {_result, exit_status} = System.cmd(cmd, args)

        if exit_status == 0 do
          :ok
        else
          :error
        end

      nil ->
        :error
    end
  end
end
