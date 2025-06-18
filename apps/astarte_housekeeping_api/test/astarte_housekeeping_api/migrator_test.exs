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

defmodule Astarte.Housekeeping.API.MigratorTest do
  use ExUnit.Case

  alias Astarte.Housekeeping.API.Migrator
  alias Astarte.Housekeeping.API.Helpers.Database
  use Mimic

  describe "run realms migrations, " do
    setup do
      astarte_instance_id = "astarte#{System.unique_integer([:positive])}"
      realm_name = "realm#{System.unique_integer([:positive])}"
      Database.setup_database_access(astarte_instance_id)
      Database.setup(realm_name)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        Database.teardown(realm_name)
      end)

      %{astarte_instance_id: astarte_instance_id, realm_name: realm_name}
    end

    # This test ensures that we're not skipping versions when creating a new realm migration
    test "for realms" do
      realm_migrations_path =
        Application.app_dir(:astarte_housekeeping_api, Path.join(["priv", "migrations", "realm"]))

      # We don't specify the .sql extension so we also check if there are migrations with the wrong extension
      realm_migrations_count =
        Path.join([realm_migrations_path, "*.sql"])
        |> Path.wildcard()
        |> Enum.count()

      assert Migrator.latest_realm_schema_version() == realm_migrations_count
    end
  end
end
