#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule Astarte.TriggerEngine.Health.Queries do
  alias Astarte.TriggerEngine.Config
  alias Astarte.Core.CQLUtils
  require Logger

  def get_astarte_health(consistency) do
    query = """
    SELECT COUNT(*)
    FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    """

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.Cluster.execute(:xandra, query, %{}, consistency: consistency),
         {:ok, _} <- Enum.fetch(page, 0) do
      :ok
    else
      :error ->
        _ =
          Logger.warning("Cannot retrieve count for astarte.realms table.",
            tag: "health_check_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warning("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end
end
