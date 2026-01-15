#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.DataAccess.Mappings do
  import Ecto.Query

  alias Astarte.Core.Mapping

  alias Astarte.DataAccess.Consistency

  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Repo

  require Logger

  @default_selection [
    :endpoint,
    :value_type,
    :reliability,
    :retention,
    :database_retention_policy,
    :database_retention_ttl,
    :expiry,
    :allow_unset,
    :explicit_timestamp,
    :endpoint_id,
    :interface_id
  ]

  @spec fetch_interface_mappings(String.t(), binary, keyword) ::
          {:ok, list(%Mapping{})} | {:error, atom}
  def fetch_interface_mappings(realm, interface_id, opts \\ []) do
    keyspace = Realm.keyspace_name(realm)

    query =
      from Endpoint,
        prefix: ^keyspace,
        where: [interface_id: ^interface_id]

    query =
      if Keyword.get(opts, :include_docs),
        do: query,
        else: query |> select(^@default_selection)

    consistency = Consistency.domain_model(:read)

    Repo.all(query, consistency: consistency)
    |> Enum.map(&Mapping.from_db_result!/1)
    |> case do
      [] -> {:error, :interface_not_found}
      mappings -> {:ok, mappings}
    end
  end

  @spec fetch_interface_mappings_map(String.t(), binary, keyword) ::
          {:ok, map()} | {:error, atom}
  def fetch_interface_mappings_map(realm_name, interface_id, opts \\ []) do
    with {:ok, mappings_list} <- fetch_interface_mappings(realm_name, interface_id, opts) do
      mappings_map =
        mappings_list
        |> Map.new(&{&1.endpoint_id, &1})

      {:ok, mappings_map}
    end
  end
end
