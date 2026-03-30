#
# This file is part of Astarte.
#
# Copyright 2019 - 2025 SECO Mind Srl
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
  @moduledoc false

  use Task, restart: :transient

  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.Migrator
  alias Astarte.Housekeeping.Realms.Queries

  require Logger

  def start_link(_init_arg), do: Task.start_link(__MODULE__, :ensure_migrated!, [])

  def ensure_migrated! do
    case Repo.checkout(&do_ensure_migrated!/0) do
      :ok ->
        :ok

      error ->
        "Error during astarte initialization: #{inspect(error)}"
        |> Logger.error(tag: "astarte_db_migration_failed")

        # Here we raise in order to notify the supervisor something went wrong
        raise "init_database failed"
    end
  end

  defp do_ensure_migrated! do
    with :ok <- Queries.initialize_database(),
         :ok <- Migrator.run_astarte_keyspace_migrations(),
         :ok <- Migrator.run_realms_migrations() do
      "Astarte database correctly initialized"
      |> Logger.info(tag: "astarte_db_initialization_finished")

      :ok
    end
  end
end
