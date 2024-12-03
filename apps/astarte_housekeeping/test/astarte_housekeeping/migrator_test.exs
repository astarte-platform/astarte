# Copyright 2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.Housekeeping.MigratorTest do
  use ExUnit.Case

  alias Astarte.Housekeeping.Migrator

  # This test ensures that we're not skipping versions when creating a new astarte migration
  test "latest astarte schema version is consistent with migrations" do
    astarte_migrations_path =
      Application.app_dir(:astarte_housekeeping, Path.join(["priv", "migrations", "astarte"]))

    # We don't specify the .sql extension so we also check if there are migrations with the wrong extension
    astarte_migrations_count =
      Path.join([astarte_migrations_path, "*"])
      |> Path.wildcard()
      |> Enum.count()

    assert Migrator.latest_astarte_schema_version() == astarte_migrations_count
  end

  # This test ensures that we're not skipping versions when creating a new realm migration
  test "latest realm schema version is consistent with migrations" do
    realm_migrations_path =
      Application.app_dir(:astarte_housekeeping, Path.join(["priv", "migrations", "realm"]))

    # We don't specify the .sql extension so we also check if there are migrations with the wrong extension
    realm_migrations_count =
      Path.join([realm_migrations_path, "*.sql"])
      |> Path.wildcard()
      |> Enum.count()

    assert Migrator.latest_realm_schema_version() == realm_migrations_count
  end
end
