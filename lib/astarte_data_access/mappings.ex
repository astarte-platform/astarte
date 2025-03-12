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

defmodule Astarte.DataAccess.Mappings do
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.XandraUtils
  require Logger

  @spec fetch_interface_mappings(String.t(), binary, keyword) ::
          {:ok, list(%Mapping{})} | {:error, atom}
  def fetch_interface_mappings(realm, interface_id, opts \\ []) do
    XandraUtils.run(realm, &do_fetch_interface_mappings(&1, &2, interface_id, opts))
  end

  defp do_fetch_interface_mappings(conn, keyspace_name, interface_id, opts) do
    include_docs =
      if Keyword.get(opts, :include_docs) do
        ", doc, description"
      else
        ""
      end

    statement = """
    SELECT endpoint, value_type, reliability, retention, database_retention_policy,
      database_retention_ttl, expiry, allow_unset, explicit_timestamp, endpoint_id,
      interface_id #{include_docs}
    FROM #{keyspace_name}.endpoints
    WHERE interface_id=:interface_id
    """

    consistency = Consistency.domain_model(:read)

    with {:ok, %Xandra.Page{} = page} <-
           XandraUtils.retrieve_page(conn, statement, %{interface_id: interface_id},
             consistency: consistency
           ) do
      to_mapping_list(page)
    end
  end

  @spec fetch_interface_mappings_map(String.t(), binary, keyword) :: {:ok, map()} | {:error, atom}
  def fetch_interface_mappings_map(realm_name, interface_id, opts \\ []) do
    with {:ok, mappings_list} <- fetch_interface_mappings(realm_name, interface_id, opts) do
      mappings_map =
        Enum.into(mappings_list, %{}, fn %Mapping{} = mapping ->
          {mapping.endpoint_id, mapping}
        end)

      {:ok, mappings_map}
    end
  end

  defp to_mapping_list(page) do
    case Enum.to_list(page) do
      [] -> {:error, :interface_not_found}
      mappings -> {:ok, Enum.map(mappings, &Mapping.from_db_result!/1)}
    end
  end
end
