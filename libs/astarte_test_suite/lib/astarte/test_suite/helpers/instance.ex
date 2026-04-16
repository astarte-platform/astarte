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

defmodule Astarte.TestSuite.Helpers.Instance do
  @moduledoc false

  import ExUnit.Callbacks, only: [on_exit: 1]
  import Astarte.TestSuite.CaseContext, only: [put!: 5, put_fixture: 3, reduce: 4]

  alias Astarte.DataAccess.Repo

  def instances(%{instance_number: instance_number} = context) do
    instance_names(instance_number)
    |> Enum.reduce(context, fn instance_name, acc ->
      put!(acc, :instances, instance_name, instance_name, nil)
    end)
  end

  def setup(context) do
    put_fixture(context, :instance_setup, %{
      instance_setup?: true
    })
  end

  def data(context) do
    {keyspaces, statements} =
      reduce(context, :instances, {[], []}, fn _instance_id,
                                               instance,
                                               nil,
                                               {keyspaces, statements} ->
        keyspace = instance_keyspace(instance)

        {
          keyspaces ++ [keyspace],
          statements ++ instance_database_statements_for(instance)
        }
      end)

    Enum.each(statements, &Repo.query!/1)

    on_exit(fn ->
      Enum.each(keyspaces, &cleanup_keyspace/1)
    end)

    context
    |> put_fixture(:instance_data, %{
      instance_keyspaces: keyspaces,
      instance_database_statements: statements,
      instance_database_ready?: true
    })
  end

  defp instance_names(1), do: ["astarte"]

  defp instance_names(instance_number) do
    1..instance_number
    |> Enum.map(fn _index ->
      "astarte" <> Integer.to_string(System.unique_integer([:positive]))
    end)
  end

  defp instance_keyspace(instance_id), do: instance_id

  defp instance_database_statements_for(instance) do
    keyspace = instance_keyspace(instance)
    [create_keyspace_statement(keyspace), create_realms_table_statement(keyspace)]
  end

  defp create_keyspace_statement(keyspace) do
    """
    CREATE KEYSPACE IF NOT EXISTS #{keyspace}
      WITH
      replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
      durable_writes = true;
    """
    |> String.trim()
  end

  defp create_realms_table_statement(keyspace) do
    """
    CREATE TABLE IF NOT EXISTS #{keyspace}.realms (
      realm_name varchar,
      device_registration_limit bigint,
      PRIMARY KEY (realm_name)
    );
    """
    |> String.trim()
  end

  defp cleanup_keyspace("astarte"), do: :ok

  defp cleanup_keyspace(keyspace) do
    keyspace
    |> drop_keyspace_statement()
    |> Repo.query!()
  end

  defp drop_keyspace_statement(keyspace) do
    "DROP KEYSPACE IF EXISTS #{keyspace};"
  end
end
