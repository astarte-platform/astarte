#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule AstarteE2E.DeviceTrigger do
  use Task

  require Logger

  alias AstarteE2E.Config

  def start_link(_opts) do
    Task.start_link(&install_device_triggers!/0)
  end

  def install_device_triggers!() do
    triggers = generate_triggers()

    realm = Config.realm!()
    realm_management_url = Config.realm_management_url!()
    astarte_jwt = Config.jwt!()

    url = Path.join([realm_management_url, "v1", realm, "triggers"])

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    installation_result =
      triggers
      |> Enum.map(&%{"data" => &1})
      |> Enum.map(&Jason.encode(&1))
      |> Enum.reduce_while(:ok, fn encoded_body, acc ->
        {:ok, body} = encoded_body
        response = HTTPoison.post!(url, body, headers)

        case {acc, response} do
          {:ok, %HTTPoison.Response{status_code: 201}} ->
            {:cont, :ok}

          _ ->
            {:halt, response}
        end
      end)

    case installation_result do
      :ok ->
        :shutdown

      errored_response ->
        Logger.warning("Failed to install a device trigger")
        {:error, errored_response}
    end
  end

  defp generate_triggers() do
    [
      %{
        name: "device_connection",
        action: %{
          http_post_url: "http://example.com/triggers"
        },
        simple_triggers: [
          %{
            type: :device_trigger,
            on: :device_connected
          }
        ]
      }
    ]
  end
end
