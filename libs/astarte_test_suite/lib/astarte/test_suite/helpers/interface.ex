#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.TestSuite.Helpers.Interface do
  @moduledoc false

  import ExUnit.Callbacks, only: [on_exit: 1]
  import Ecto.Query

  import Astarte.Core.CQLUtils, only: [interface_name_to_table_name: 2]
  import Astarte.Core.Generators.Interface, only: [interface: 0]
  import Astarte.DataAccess.Adapters.Interface, only: [from_core_interface_to_change: 1]

  import Astarte.TestSuite.CaseContext, only: [get!: 3, put!: 5, put_fixture: 3, reduce: 4]

  alias Astarte.Core.Interface

  alias Astarte.DataAccess.Realms.Endpoint, as: EndpointData
  alias Astarte.DataAccess.Realms.Interface, as: InterfaceData
  alias Astarte.DataAccess.Repo

  def interfaces(%{interface_number: interface_number} = context) do
    reduce(context, :realms, context, fn realm_id, _realm, _instance_id, acc ->
      interface()
      |> Enum.take(interface_number)
      |> Enum.reduce(acc, fn %Interface{name: name, major_version: major_version} = interface,
                             inner_acc ->
        interface_key = interface_name_to_table_name(name, major_version)
        put!(inner_acc, :interfaces, interface_key, interface, realm_id)
      end)
    end)
  end

  def data(context) do
    entries_by_keyspace = entries_by_keyspace(context)

    results = insert_entries(entries_by_keyspace)

    on_exit(fn -> delete_entries(entries_by_keyspace) end)

    context
    |> put_fixture(:interface_data, %{
      interface_database_results: results,
      interfaces_registered?: true
    })
  end

  defp entries_by_keyspace(context) do
    reduce(context, :interfaces, %{}, fn _interface_id, interface, realm_id, acc ->
      realm = get!(context, :realms, realm_id)
      keyspace = realm.instance_id
      entry = interface_entry(interface)

      Map.update(acc, keyspace, [entry], &(&1 ++ [entry]))
    end)
  end

  defp interface_entry(interface) do
    interface
    |> from_core_interface_to_change()
  end

  defp insert_entries(entries_by_keyspace) do
    Enum.map(entries_by_keyspace, fn {keyspace, entries} ->
      endpoint_result =
        entries
        |> Enum.flat_map(&Map.fetch!(&1, :endpoints))
        |> Enum.map(&insert_endpoint(&1, keyspace))

      interface_result =
        entries
        |> Enum.map(&Map.fetch!(&1, :interface))
        |> Enum.map(&insert_interface(&1, keyspace))

      %{keyspace: keyspace, result: {endpoint_result, interface_result}}
    end)
  end

  # TODO: use the procedure in `astarte_data_access` asap,
  # TODO: handling the error as per the comment
  defp insert_endpoint(changes, keyspace) do
    changeset = EndpointData.changeset(%EndpointData{}, changes)
    {:ok, struct} = Repo.insert(changeset, prefix: keyspace)
    struct
    # case Repo.insert(changeset, prefix: keyspace) do
    #   {:ok, struct} ->
    #     struct

    #   {:error, reason} ->
    #     raise RuntimeError, "failed to insert endpoint into #{keyspace}: #{inspect(reason)}"
    # end
  end

  # TODO: use the procedure in `astarte_data_access` asap,
  # TODO: handling the error as per the comment
  defp insert_interface(changes, keyspace) do
    changeset = InterfaceData.changeset(%InterfaceData{}, changes)
    {:ok, struct} = Repo.insert(changeset, prefix: keyspace)
    struct
    # case Repo.insert(changeset, prefix: keyspace) do
    #   {:ok, struct} ->
    #     struct

    #   {:error, reason} ->
    #     raise RuntimeError, "failed to insert interface into #{keyspace}: #{inspect(reason)}"
    # end
  end

  defp delete_entries(entries_by_keyspace) do
    Enum.each(entries_by_keyspace, fn {keyspace, entries} ->
      Enum.map(entries, &Map.fetch!(&1, :interface))
      |> Enum.each(&delete_interface(&1, keyspace))

      Enum.flat_map(entries, &Map.fetch!(&1, :endpoints))
      |> Enum.each(&delete_endpoint(&1, keyspace))
    end)
  end

  defp delete_interface(%{name: name, major_version: major_version}, keyspace) do
    from(i in InterfaceData,
      where: i.name == ^name and i.major_version == ^major_version
    )
    |> Repo.safe_delete_all(prefix: keyspace)
  end

  defp delete_endpoint(%{interface_id: interface_id, endpoint_id: endpoint_id}, keyspace) do
    from(e in EndpointData,
      where: e.interface_id == ^interface_id and e.endpoint_id == ^endpoint_id
    )
    |> Repo.safe_delete_all(prefix: keyspace)
  end
end
