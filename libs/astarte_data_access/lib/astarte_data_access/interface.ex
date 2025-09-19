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

defmodule Astarte.DataAccess.Interface do
  require Logger
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.Consistency

  import Ecto.Query

  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Repo

  require Logger

  @default_selection [
    :name,
    :major_version,
    :minor_version,
    :interface_id,
    :type,
    :ownership,
    :aggregation,
    :storage,
    :storage_type,
    :automaton_transitions,
    :automaton_accepting_states
  ]

  @spec retrieve_interface_row(String.t(), String.t(), integer, keyword()) ::
          {:ok, Interface.t()} | {:error, atom}
  def retrieve_interface_row(realm, interface_name, major_version, opts \\ []) do
    keyspace = Realm.keyspace_name(realm)

    query =
      from Interface,
        prefix: ^keyspace,
        where: [name: ^interface_name, major_version: ^major_version]

    query =
      if Keyword.get(opts, :include_docs),
        do: query,
        else: query |> select(^@default_selection)

    consistency = Consistency.domain_model(:read)
    Repo.fetch_one(query, error: :interface_not_found, consistency: consistency)
  end

  @spec fetch_interface_descriptor(String.t(), String.t(), non_neg_integer) ::
          {:ok, %InterfaceDescriptor{}} | {:error, atom}
  def fetch_interface_descriptor(realm_name, interface_name, major_version) do
    with {:ok, interface} <- retrieve_interface_row(realm_name, interface_name, major_version) do
      InterfaceDescriptor.from_db_result(interface)
    end
  end

  @spec check_if_interface_exists(String.t(), String.t(), non_neg_integer) ::
          :ok | {:error, atom}
  def check_if_interface_exists(realm, interface_name, major_version) do
    keyspace = Realm.keyspace_name(realm)

    query =
      from Interface,
        prefix: ^keyspace,
        where: [name: ^interface_name, major_version: ^major_version]

    consistency = Consistency.domain_model(:read)

    case Repo.some?(query, consistency: consistency) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :interface_not_found}
    end
  end
end
