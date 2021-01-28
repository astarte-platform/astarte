#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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
  alias CQEx.Query
  require Logger

  @spec fetch_interface_mappings(:cqerl.client(), binary, keyword) ::
          {:ok, list(%Mapping{})} | {:error, atom}
  def fetch_interface_mappings(db_client, interface_id, opts \\ []) do
    include_docs_statement =
      if Keyword.get(opts, :include_docs) do
        ", doc, description"
      else
        ""
      end

    mappings_statement = """
    SELECT endpoint, value_type, reliability, retention, database_retention_policy,
      database_retention_ttl, expiry, allow_unset, explicit_timestamp, endpoint_id,
      interface_id #{include_docs_statement}
    FROM endpoints
    WHERE interface_id=:interface_id
    """

    mappings_query =
      Query.new()
      |> Query.statement(mappings_statement)
      |> Query.put(:interface_id, interface_id)
      |> Query.consistency(:quorum)

    with {:ok, result} <- Query.call(db_client, mappings_query) do
      mappings = Enum.map(result, &Mapping.from_db_result!/1)

      {:ok, mappings}
    else
      %{acc: _, msg: error_message} ->
        Logger.warn("fetch_interface_mappings: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("fetch_interface_mappings: failed with reason #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  @spec fetch_interface_mappings_map(:cqerl.client(), binary, keyword) ::
          {:ok, map()} | {:error, atom}
  def fetch_interface_mappings_map(db_client, interface_id, opts \\ []) do
    with {:ok, mappings_list} <- fetch_interface_mappings(db_client, interface_id, opts) do
      mappings_map =
        Enum.into(mappings_list, %{}, fn %Mapping{} = mapping ->
          {mapping.endpoint_id, mapping}
        end)

      {:ok, mappings_map}
    end
  end
end
