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

  import Ecto.Query

  alias Astarte.DataUpdaterPlant.Repo
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm

  def retrieve_policy_name(realm_name, trigger_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    trigger_id =
      trigger_id
      |> :uuid.uuid_to_string()
      |> to_string()

    query =
      from kvstore in KvStore,
        prefix: ^keyspace_name,
        where: kvstore.group == "trigger_to_policy" and kvstore.key == ^trigger_id,
        select: kvstore.value

    case Repo.one(query) do
      nil -> {:error, :policy_not_found}
      value -> {:ok, value}
    end
  end
end
