#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind srl
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

defmodule Astarte.Events.AMQP.Vhost do
  require Logger
  alias Astarte.Events.AMQP

  @spec create_vhost(String.t()) :: :ok | :error
  def create_vhost(realm) do
    vhost_name = vhost_name(realm)

    case AMQP.put("/api/vhosts/#{vhost_name}", "") do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        :ok

      {:ok, %HTTPoison.Response{status_code: 204}} ->
        "requested vhost already exists: skipping creation"
        |> Logger.warning(realm: realm)

        :ok

      {:ok, response} ->
        "error during vhost creation: unexpected response #{inspect(response)}"
        |> Logger.error(realm: realm)

        :error

      {:error, reason} ->
        "error during vhost creation: http error #{inspect(reason)}"
        |> Logger.error(realm: realm)

        :error
    end
  end

  def vhost_name(realm_name) do
    astarte_instance = Astarte.DataAccess.Config.astarte_instance_id!()
    "#{astarte_instance}_#{realm_name}"
  end
end
