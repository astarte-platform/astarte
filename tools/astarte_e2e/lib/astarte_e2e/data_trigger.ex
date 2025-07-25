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

defmodule AstarteE2E.DataTrigger do
  require Logger

  use Task

  alias AstarteE2E.Config

  def start_link(opts) do
    Task.start_link(__MODULE__, :install_data_trigger!, [opts])
  end

  def install_data_trigger!(opts) do
    device_id = Keyword.fetch!(opts, :device_id)
    base_url = Config.realm_management_url!()
    realm = Config.realm!()
    astarte_jwt = Config.jwt!()

    url = Path.join([base_url, "v1", realm, "triggers"])

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    triggers = [
      %{
        name: "valuetrigger-datastream",
        device_id: device_id,
        simple_trigger: %{
          type: "data_trigger",
          on: "incoming_data",
          interface_name: "org.astarte-platform.e2etest.SimpleDatastream",
          interface_major: 1,
          match_path: "/*",
          value_match_operator: "*"
        }
      },
      %{
        name: "valuetrigger-properties",
        device_id: device_id,
        simple_trigger: %{
          type: "data_trigger",
          on: "incoming_data",
          interface_name: "org.astarte-platform.e2etest.SimpleProperties",
          interface_major: 1,
          match_path: "/*",
          value_match_operator: "*"
        }
      }
    ]

    Enum.reduce_while(triggers, :ok, fn trigger, :ok ->
      body = Jason.encode!(%{"data" => trigger})

      case HTTPoison.post(url, body, headers) do
        {:ok, %HTTPoison.Response{status_code: 201}} ->
          {:cont, :ok}

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          {:halt, {:error, %{status: code, body: body}}}

        {:error, %HTTPoison.Error{} = error} ->
          {:halt, {:error, error}}
      end
    end)
  end
end
