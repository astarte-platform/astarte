#
# This file is part of Astarte.
#
# Copyright 2018 - 2024 SECO Mind Srl
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
  alias Astarte.DataAccess.XandraUtils

  @interface_row_default_selector "name, major_version, minor_version, interface_id, type, ownership, aggregation,
  storage, storage_type, automaton_transitions, automaton_accepting_states"

  @spec retrieve_interface_row(String.t(), String.t(), integer, keyword()) ::
          {:ok, keyword()} | {:error, atom}
  def retrieve_interface_row(realm, interface_name, major_version, opts \\ []) do
    XandraUtils.run(
      realm,
      &do_retrieve_interface_row(&1, &2, interface_name, major_version, opts)
    )
  end

  def do_retrieve_interface_row(conn, keyspace_name, interface_name, major_version, opts) do
    selector = if opts[:include_docs], do: "*", else: @interface_row_default_selector

    statement = """
    SELECT #{selector}
    FROM #{keyspace_name}.interfaces
    WHERE name=:name AND major_version=:major_version
    """

    params = %{
      name: interface_name,
      major_version: major_version
    }

    consistency = Consistency.domain_model(:read)

    with {:ok, %Xandra.Page{} = page} <-
           XandraUtils.retrieve_page(conn, statement, params, consistency: consistency) do
      case Enum.to_list(page) do
        [] -> {:error, :interface_not_found}
        [row] -> {:ok, row}
      end
    end
  end

  @spec fetch_interface_descriptor(String.t(), String.t(), non_neg_integer) ::
          {:ok, %InterfaceDescriptor{}} | {:error, atom}
  def fetch_interface_descriptor(realm_name, interface_name, major_version) do
    with {:ok, interface_row} <-
           retrieve_interface_row(realm_name, interface_name, major_version) do
      InterfaceDescriptor.from_db_result(interface_row)
    end
  end

  @spec check_if_interface_exists(String.t(), String.t(), non_neg_integer) ::
          :ok | {:error, atom}
  def check_if_interface_exists(realm, interface_name, major_version) do
    XandraUtils.run(
      realm,
      &do_check_if_interface_exists(&1, &2, interface_name, major_version)
    )
  end

  defp do_check_if_interface_exists(conn, keyspace_name, interface_name, major_version) do
    statement = """
    SELECT COUNT(*)
    FROM #{keyspace_name}.interfaces
    WHERE name=:name AND major_version=:major_version
    """

    params = %{
      name: interface_name,
      major_version: major_version
    }

    consistency = Consistency.domain_model(:read)

    with {:ok, %Xandra.Page{} = page} <-
           XandraUtils.retrieve_page(conn, statement, params, consistency: consistency) do
      case Enum.to_list(page) do
        [%{count: 1}] ->
          :ok

        [%{count: 0}] ->
          {:error, :interface_not_found}
      end
    end
  end
end
