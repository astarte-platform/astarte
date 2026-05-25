#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.Database.Migrations.Realm.MigrateSchemaVersion do
  @moduledoc false

  use Ecto.Migration

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.KvStore

  def up do
    opts = [prefix: prefix(), consistency: Consistency.domain_model(:read)]

    case KvStore.fetch_value("astarte", "schema_version", :big_integer, opts) do
      {:ok, schema_version} -> populate_migrations(schema_version)
      _error -> :ok
    end
  end

  defp populate_migrations(schema_version) do
    now = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    # there are 2 extra migrations (migrate_schema_version, init_database)
    migration_version = schema_version + 2

    migrations_table =
      Application.get_env(:astarte_data_access, repo(), [])
      |> Keyword.get(:migration_source, "schema_migrations")

    query = "INSERT INTO #{prefix()}.#{migrations_table} (version, inserted_at) values (?, ?)"

    batch_queries =
      for migration_id <- 1..migration_version//1 do
        {query, [migration_id, now]}
      end

    batch = %Exandra.Batch{queries: batch_queries}

    :ok = Exandra.execute_batch(repo(), batch, consistency: Consistency.domain_model(:write))
  end
end
