#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Helpers.Trigger do
  @moduledoc """
  Helper module for trigger operations.
  """

  alias Astarte.Core.Triggers.Trigger
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  import Ecto.Query

  def install_trigger(realm_name, trigger) do
    keyspace = Realm.keyspace_name(realm_name)

    insert_by_name = %{
      group: "triggers-by-name",
      key: trigger.name,
      value: trigger.trigger_uuid,
      value_type: :uuid
    }

    uuid_string =
      trigger.trigger_uuid
      |> UUID.binary_to_string!()

    insert = %{
      group: "triggers",
      key: uuid_string,
      value: Trigger.encode(trigger)
    }

    :ok = KvStore.insert(insert_by_name, prefix: keyspace)
    :ok = KvStore.insert(insert, prefix: keyspace)
  end

  def remove_triggers(realm_name, triggers) do
    keyspace = Realm.keyspace_name(realm_name)

    trigger_names = triggers |> Enum.map(& &1.name)
    string_ids = triggers |> Enum.map(& &1.trigger_uuid) |> Enum.map(&UUID.binary_to_string!/1)

    trigger_names
    |> Enum.chunk_every(100)
    |> Enum.each(fn name_chunk ->
      from(k in KvStore,
        prefix: ^keyspace,
        where: k.group == "triggers-by-name" and k.key in ^name_chunk
      )
      |> Repo.delete_all()
    end)

    string_ids
    |> Enum.chunk_every(100)
    |> Enum.each(fn id_chunk ->
      from(k in KvStore, prefix: ^keyspace, where: k.group == "triggers" and k.key in ^id_chunk)
      |> Repo.delete_all()
    end)
  end

  def remove_trigger(realm_name, trigger), do: remove_triggers(realm_name, [trigger])
end
