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
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  require Logger

  import Ecto.Query

  def list_policies(realm_name) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from k in KvStore,
        prefix: ^keyspace_name,
        where: k.group == "trigger_policy"

    case Repo.fetch_all(query, consistency: Consistency.domain_model(:read)) do
      {:ok, policies} ->
        {:ok, Enum.map(policies, &extract_name_and_data/1)}

      {:error, reason} ->
        _ = Logger.warning("Could not list policies, reason: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def list_realms do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from r in Realm,
        prefix: ^keyspace_name,
        select: r.realm_name

    with {:error, reason} <- Repo.fetch_all(query, consistency: Consistency.domain_model(:read)) do
      _ = Logger.warning("Could not list realms, reason: #{inspect(reason)}")
      {:error, reason}
    end
  end

  defp extract_name_and_data(%KvStore{key: name, value: data}) do
    {name, data}
  end
end
