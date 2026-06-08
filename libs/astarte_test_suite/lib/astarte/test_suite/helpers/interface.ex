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
  import Astarte.Core.Generators.Interface, only: [interface: 0]
  import Astarte.DataAccess.Generators.Interface, only: [from_core: 1]
  import Astarte.TestSuite.CaseContext, only: [get!: 3, put!: 5, put_fixture: 3, reduce: 4]
  import Ecto.Query

  alias Astarte.Core.Interface
  alias Astarte.DataAccess.Realms.Interface, as: InterfaceData
  alias Astarte.DataAccess.Repo

  def interfaces(%{interface_number: interface_number} = context) do
    reduce(context, :realms, context, fn realm_id, _realm, _instance_id, acc ->
      interface()
      |> Enum.take(interface_number)
      |> Enum.reduce(acc, fn %Interface{name: name} = interface, inner_acc ->
        put!(inner_acc, :interfaces, name, interface, realm_id)
      end)
    end)
  end

  def data(context) do
    entries_by_keyspace = entries_by_keyspace(context)

    results =
      Enum.map(entries_by_keyspace, fn {keyspace, entries} ->
        case Repo.safe_insert_all(InterfaceData, entries, prefix: keyspace) do
          {:ok, result} ->
            %{keyspace: keyspace, result: result}

          {:error, reason} ->
            raise RuntimeError,
                  "failed to insert interfaces into #{keyspace}: #{inspect(reason)}"
        end
      end)

    on_exit(fn ->
      Enum.each(entries_by_keyspace, fn {keyspace, _entries} ->
        delete_interfaces(keyspace, Map.fetch!(entries_by_keyspace, keyspace))
      end)
    end)

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
    |> from_core()
    |> Enum.at(0)
    |> Map.from_struct()
    |> Map.delete(:__meta__)
  end

  defp delete_interfaces(keyspace, entries) do
    Enum.each(entries, fn %{name: name, major_version: major_version} ->
      InterfaceData
      |> where([interface], interface.name == ^name and interface.major_version == ^major_version)
      |> Repo.safe_delete_all(prefix: keyspace)
    end)
  end
end
