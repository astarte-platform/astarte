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

defmodule Astarte.DataUpdaterPlant.TriggerPolicy.Queries do
  require Logger
  alias Astarte.Core.CQLUtils
  alias Astarte.DataUpdaterPlant.Config

  def retrieve_policy_name(realm_name, trigger_id) do
    trigger_id =
      trigger_id
      |> :uuid.uuid_to_string()
      |> to_string()

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    Xandra.Cluster.run(:xandra, &do_retrieve_policy_name(&1, keyspace_name, trigger_id))
  end

  defp do_retrieve_policy_name(conn, keyspace_name, trigger_id) do
    retrieve_statement =
      "SELECT value FROM #{keyspace_name}.kv_store WHERE group='trigger_to_policy' AND key=:trigger_id;"

    with {:ok, prepared} <- Xandra.prepare(conn, retrieve_statement),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"trigger_id" => trigger_id}) do
      case Enum.to_list(page) do
        [%{"value" => policy_name}] -> {:ok, policy_name}
        [] -> {:error, :policy_not_found}
      end
    else
      {:error, error} ->
        Logger.warning("Database error #{inspect(error)}", tag: "retrieve_policy_name_db_error")
        {:error, error}
    end
  end
end
