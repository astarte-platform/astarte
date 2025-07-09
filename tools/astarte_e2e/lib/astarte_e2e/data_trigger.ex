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

  use Supervisor
  use Task

  alias AstarteE2E.Config

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    device_id = Keyword.fetch!(opts, :device_id)

    child = %{
      id: :install_data_trigger,
      start: {Task, :start_link, [fn -> install_data_trigger!(device_id) end]},
      type: :worker,
      restart: :transient
    }

    Supervisor.init([child], strategy: :one_for_one)
  end

  def install_data_trigger!(device_id) do
    url = trigger_install_url!()

    headers = [
      {"Authorization", "Bearer #{Config.jwt!()}"},
      {"Accept", "application/json"}
    ]

    trigger =
      %{
        name: "valuetrigger-#{device_id}",
        device_id: device_id,
        simple_trigger: %{
          type: "data_trigger",
          on: "incoming_data",
          interface_name: "*",
          interface_major: 1,
          match_path: "/*",
          value_match_operator: "*"
        }
      }

    body = Jason.encode!(%{"data" => trigger})

    %HTTPoison.Response{status_code: 201, body: response} = HTTPoison.post!(url, body, headers)

    :ok
  end

  defp trigger_install_url!() do
    base_url = Config.realm_management_url!()
    realm = Config.realm!()
    "#{base_url}/v1/#{realm}/triggers"
  end
end
