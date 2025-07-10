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

defmodule AstarteE2E.Trigger do
  use Task, restart: :transient

  require Logger

  # alias Astarte.Core.Generators.Trigger, as: TriggerGenerator
  alias AstarteE2E.Config

  def start_link(opts) do
    realm_result = Keyword.fetch(opts, :realm)

    case realm_result do
      {:ok, realm} -> Task.start_link(__MODULE__, :install_triggers!, realm)
      _ ->
        Logger.warning("Trying to create a trigger without realm or name")
        {:error, :invalid_args}
    end
  end

  def install_triggers!(realm) do
    # params = opts
    # trigger = TriggerGenerator.trigger(params)
    # TODO: actual trigger generation
    triggers = generate_triggers()

    astarte_realm_management_url = Config.realm_management_url!()
    astarte_jwt = Config.jwt!()

    url = "#{astarte_realm_management_url}/v1/#{realm}/triggers"

    headers = [
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    installation_result = triggers
    |> Enum.map(& %{ "data" => &1 })
    |> Enum.reduce_while(:ok, fn body, acc ->
      response = HTTPoison.post!(url, body, headers)
      case {acc, response} do
        {:ok, %HTTPoison.Response{status_code: 201}} ->
          {:cont, :ok}
        _ -> {:halt, response}
      end
    end)

    installation_result
  end

  defp generate_triggers() do
    [%{
      name: "device_connection",
      action: %{
        http_url: "http://example.com/triggers",
        http_method: "post"
      },
      simple_triggers: [%{
        type: :device_trigger,
        on: :device_creation,
      }]
    }]
  end
end
