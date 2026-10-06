#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.TestSuite.Helpers.Realm do
  @moduledoc false
  import Ecto.Query
  import ExUnit.Callbacks, only: [on_exit: 1]

  import Astarte.TestSuite.CaseContext, only: [ids: 2, put!: 5, put_fixture: 3, reduce: 4]

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Realms.Realm, as: RealmData
  alias Astarte.DataAccess.Repo

  alias Astarte.Core.Generators.Realm, as: RealmGenerator

  def realm_names(%{realm_number: realm_number} = context),
    do:
      RealmGenerator.realm_name()
      |> Enum.take(realm_number * instances_count(context))
      |> unique_realm_names()

  def realms(%{realm_names: realm_names} = context) do
    realm_number =
      case Map.fetch(context, :realm_number) do
        {:ok, value} -> value
        :error -> names_count(realm_names)
      end

    {realm_context, _remaining_names} =
      reduce(context, :instances, {context, realm_names}, fn instance_id,
                                                             _instance,
                                                             nil,
                                                             {acc, names} ->
        {instance_realm_names, remaining_names} = Enum.split(names, realm_number)

        next_context =
          Enum.reduce(instance_realm_names, acc, fn realm_name, inner_acc ->
            put!(
              inner_acc,
              :realms,
              realm_name,
              realm_entry(instance_id, realm_name),
              instance_id
            )
          end)

        {next_context, remaining_names}
      end)

    realm_context
  end

  def data(context) do
    instance_keyspace = Map.get(context, :instance_keyspace)

    realms =
      reduce(context, :realms, [], fn _realm_id, %{id: realm_name}, _instance_id, realms ->
        keyspace = RealmData.keyspace_name(realm_name)

        create_keyspace!(keyspace)
        :ok = Database.migrate_realm(realm_name)
        insert_realm!(realm_name)

        [{realm_name, keyspace, instance_keyspace} | realms]
      end)

    on_exit(fn ->
      Enum.each(realms, &delete_realm!/1)
    end)

    context
    |> put_fixture(:realm_data, %{
      realm_keyspaces:
        Enum.map(realms, fn {_realm_name, keyspace, _instance_keyspace} -> keyspace end),
      realms_ready?: true
    })
  end

  defp instances_count(context), do: context |> ids(:instances) |> length()

  defp names_count(realm_names), do: length(realm_names)

  defp unique_realm_names(realm_names), do: Enum.map(realm_names, &unique_realm_name/1)

  defp unique_realm_name(realm_name) do
    suffix = Integer.to_string(System.unique_integer([:positive]))
    prefix_length = min(byte_size(realm_name), 48 - byte_size(suffix))

    binary_part(realm_name, 0, prefix_length) <> suffix
  end

  defp realm_entry(instance_id, realm_name),
    do: %{id: realm_name, name: realm_name, instance_id: instance_id}

  defp create_keyspace!(keyspace) do
    """
    CREATE KEYSPACE IF NOT EXISTS #{keyspace}
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
    """
    |> String.trim()
    |> Repo.query!()
  end

  defp insert_realm!(realm_name) do
    %RealmData{realm_name: realm_name}
    |> Repo.insert!(
      prefix: RealmData.astarte_keyspace_name(),
      consistency: Consistency.domain_model(:write)
    )
  end

  defp delete_realm!({realm_name, keyspace, instance_keyspace}) do
    RealmData
    |> where([realm], realm.realm_name == ^realm_name)
    |> Repo.safe_delete_all(
      prefix: instance_keyspace,
      consistency: Consistency.domain_model(:write)
    )

    Repo.query!("DROP KEYSPACE IF EXISTS #{keyspace};")
  end
end
