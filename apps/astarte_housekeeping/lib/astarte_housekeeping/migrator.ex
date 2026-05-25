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

defmodule Astarte.Housekeeping.Migrator do
  @moduledoc false

  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.Events.AMQP.Vhost
  alias Astarte.Secrets

  require Logger

  def run_realms_migrations do
    _ = Logger.info("Starting to migrate Realms.", tag: "realms_migration_started")

    realm_names = Realm.list_realm_names()

    for realm_name <- realm_names do
      "Starting to migrate realm."
      |> Logger.info(tag: "realm_migration_started", realm: realm_name)

      :ok = Vhost.create_vhost(realm_name)
      :ok = ensure_realm_kek(realm_name)
    end

    :ok
  end

  defp ensure_realm_kek(realm_name) do
    case Secrets.create_realm_kek(realm_name) do
      {:ok, _key} ->
        :ok

      :error ->
        Logger.error("Failed to create realm KEK for realm #{realm_name}",
          tag: "realm_kek_creation_failed",
          realm: realm_name
        )

        {:error, :realm_kek_creation_failed}
    end
  end
end
