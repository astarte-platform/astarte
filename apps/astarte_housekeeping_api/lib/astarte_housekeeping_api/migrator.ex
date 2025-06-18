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

defmodule Astarte.Housekeeping.API.Migrator do
  require Logger

  def latest_realm_schema_version do
    {version, _, _} =
      realm_migrations_path()
      |> collect_migrations(sorting_order: :descending)
      |> hd()

    version
  end

  defp realm_migrations_path do
    Application.app_dir(:astarte_housekeeping_api, Path.join(["priv", "migrations", "realm"]))
  end

  defp collect_migrations(migrations_path, opts) do
    sorting_function =
      case Keyword.get(opts, :sorting_order, :ascending) do
        :ascending ->
          fn a, b -> a <= b end

        :descending ->
          fn a, b -> a >= b end
      end

    Path.join([migrations_path, "*.sql"])
    |> Path.wildcard()
    |> Enum.map(&extract_migration_info/1)
    |> Enum.filter(&(&1 != nil))
    |> Enum.sort(sorting_function)
  end

  defp extract_migration_info(file) do
    base = Path.basename(file)

    case Integer.parse(Path.rootname(base)) do
      {version, "_" <> name} -> {version, name, file}
      _ -> nil
    end
  end
end
