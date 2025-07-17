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

defmodule AstarteE2E.Realm do
  use Supervisor
  use Task

  require Logger

  alias AstarteE2E.Config

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    realm = Keyword.fetch!(opts, :realm_name)
    jwt_public_key_pem = Keyword.fetch!(opts, :jwt_public_key_pem)

    child = %{
      id: :create_realm,
      start: {Task, :start_link, [fn -> create_realm!(realm, jwt_public_key_pem) end]},
      type: :worker,
      restart: :transient
    }

    Supervisor.init([child], strategy: :one_for_one)
  end

  defp create_realm!(realm, jwt_public_key_pem) do
    housekeeping_url = Config.housekeeping_url!()
    astarte_jwt = Config.jwt!()

    url = "#{housekeeping_url}/v1/realms"

    body =
      %{
        data: %{
          realm_name: realm,
          jwt_public_key_pem: jwt_public_key_pem
        }
      }
      |> Jason.encode!()

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    %HTTPoison.Response{status_code: 201, body: response} = HTTPoison.post!(url, body, headers)

    response
  end
end
