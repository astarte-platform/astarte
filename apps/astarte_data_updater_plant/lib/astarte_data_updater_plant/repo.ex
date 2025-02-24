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

defmodule Astarte.DataUpdaterPlant.Repo do
  use Ecto.Repo, otp_app: :astarte_data_updater_plant, adapter: Exandra
  alias Astarte.DataUpdaterPlant.Config
  require Logger

  @impl Ecto.Repo
  def init(_context, config) do
    config =
      Config.xandra_options!()
      |> Keyword.merge(config)

    {:ok, config}
  end

  def fetch_one(queryable, opts \\ []) do
    try do
      one(queryable, opts)
    catch
      error ->
        handle_xandra_error(error)
    end
  end

  defp handle_xandra_error(%Xandra.ConnectionError{} = error) do
    _ =
      Logger.warning("Database connection error #{Exception.message(error)}.",
        tag: "database_connection_error"
      )

    {:error, :database_connection_error}
  end

  defp handle_xandra_error(%Xandra.Error{} = error) do
    %Xandra.Error{message: message} = error

    case Regex.run(~r/Keyspace (.*) does not exist/, message) do
      [_message, keyspace] ->
        Logger.warning("Keyspace #{keyspace} does not exist.",
          tag: "realm_not_found"
        )

        {:error, :realm_not_found}

      nil ->
        _ =
          Logger.warning(
            "Database error: #{Exception.message(error)}.",
            tag: "database_error"
          )

        {:error, :database_error}
    end
  end
end
