#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.TriggerEngine.AMQPConsumer.Queries do
  alias Astarte.Core.CQLUtils
  alias Astarte.TriggerEngine.Config
  require Logger

  def list_policies(realm_name) do
    Xandra.Cluster.run(:xandra, &do_list_policies(&1, realm_name))
  end

  defp do_list_policies(conn, realm_name) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    list_policies_statement =
      "SELECT * FROM #{keyspace_name}.kv_store WHERE group='trigger_policy';"

    with {:ok, prepared} <-
           Xandra.prepare(conn, list_policies_statement),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{}),
         policy_list <- Enum.map(page, &extract_name_and_data/1) do
      {:ok, policy_list}
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def list_realms do
    Xandra.Cluster.run(:xandra, &do_list_realms/1)
  end

  def do_list_realms(conn) do
    query = """
    SELECT realm_name
    FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms;
    """

    case Xandra.execute(conn, query, %{}, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        {:ok, Enum.map(page, &extract_realm_name/1)}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warning("Database error while listing realms: #{inspect(err)}.",
            tag: "database_error"
          )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error while listing realms: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp extract_name_and_data(%{"key" => name, "value" => data}) do
    {name, data}
  end

  defp extract_realm_name(%{"realm_name" => name}) do
    name
  end
end
