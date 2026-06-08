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
  require Logger

  alias AstarteE2E.Config

  def create_realm!() do
    base_url = Config.housekeeping_url!()
    astarte_jwt = Config.housekeeping_jwt!()
    {:ok, realm} = Config.realm()
    jwt_public_key_pem = Config.jwt_public_key_pem!()

    url = Path.join([base_url, "v1", "realms"]) <> "?async_operation=false"

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

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        :ok

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        raise "Failed to create realm: #{code} #{body}"

      {:error, %HTTPoison.Error{} = error} ->
        raise "HTTP error while creating realm: #{inspect(error)}"
    end
  end
end
