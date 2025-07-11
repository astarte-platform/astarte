#
# This file is part of Astarte.
#
# Copyright 2019 - 2025 Ispirata Srl
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

defmodule Astarte.Housekeeping.ReleaseTasks do
  require Logger

  alias Astarte.DataAccess
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Migrator
  alias Astarte.Housekeeping.Realms.Queries

  @start_apps [
    :ecto,
    :logger,
    :crypto,
    :ssl
  ]

  def init_database do
    :ok = start_services()

    with {:ok, exists?} <- wait_connection_and_check_astarte_keyspace() do
      unless exists? do
        _ =
          Logger.info("Astarte keyspace not found, creating it",
            tag: "astarte_db_initialization_started"
          )

        :ok = Queries.initialize_database()
      else
        :ok
      end
    else
      {:error, reason} ->
        _ =
          Logger.error("Can't check if Astarte keyspace exists: #{inspect(reason)}",
            tag: "astarte_db_initialization_failed"
          )

        raise "init_database failed"
    end

    :ok = stop_services()
  end

  def migrate do
    :ok = start_services()

    Logger.info("Starting to migrate the database", tag: "astarte_db_migration_started")

    case wait_connection_and_check_astarte_keyspace() do
      {:ok, true} ->
        with :ok <- Migrator.run_astarte_keyspace_migrations(),
             :ok <- Migrator.run_realms_migrations() do
          :ok
        else
          {:error, reason} ->
            Logger.error("Cannot migrate the database: #{inspect(reason)}",
              tag: "astarte_db_migration_failed"
            )

            raise "migrate failed"
        end

        :ok = stop_services()

      {:ok, false} ->
        Logger.error("Cannot migrate the database, Astarte keyspace does not exist",
          tag: "astarte_db_migration_failed"
        )

        raise "migrate failed"
    end
  end

  defp wait_connection_and_check_astarte_keyspace(retries \\ 60) do
    case Queries.is_astarte_keyspace_existing() do
      {:ok, exists?} ->
        {:ok, exists?}

      {:error, :database_connection_error} ->
        if retries > 0 do
          :timer.sleep(1000)
          wait_connection_and_check_astarte_keyspace(retries - 1)
        else
          {:error, :database_connection_error}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_services do
    DataAccess.Config.validate!()
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Load astarte_data_access, without starting it. This makes the application env accessible.
    :ok = Application.load(:astarte_data_access)

    _ = Logger.info("Starting Xandra connection to #{inspect(Config.xandra_nodes!())}")

    xandra_options = Config.xandra_options!()

    {:ok, _pid} = DataAccess.start_link(xandra_options: xandra_options)

    :ok
  end

  defp stop_services do
    _ =
      Logger.info("Astarte database correctly initialized",
        tag: "astarte_db_initialization_finished"
      )

    :init.stop()
  end
end
