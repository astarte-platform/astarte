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

defmodule Astarte.TestSuite.Helpers.Instance do
  @moduledoc false

  import ExUnit.Callbacks, only: [on_exit: 1]
  import Astarte.TestSuite.CaseContext, only: [put!: 5, put_fixture: 3]

  alias Astarte.DataAccess.Config
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  def setup(context) do
    instance_id = unique_instance_id()
    bind_instance(instance_id)
    instance_keyspace = Realm.astarte_keyspace_name()

    context
    |> put!(:instances, instance_id, instance_id, nil)
    |> put_fixture(:instance_setup, %{
      instance_id: instance_id,
      instance_keyspace: instance_keyspace,
      instance_setup?: true
    })
  end

  def data(%{instance_keyspace: instance_keyspace} = context) do
    statement = create_keyspace_statement(instance_keyspace)
    Repo.query!(statement)
    :ok = Database.migrate()

    on_exit(fn ->
      cleanup_keyspace(instance_keyspace)
    end)

    context
    |> put_fixture(:instance_data, %{
      instance_keyspaces: [instance_keyspace],
      instance_database_statements: [statement],
      instance_database_ready?: true
    })
  end

  def bind(%{instance_id: instance_id}) do
    bind_instance(instance_id)
    :ok
  end

  defp unique_instance_id do
    "instance" <> Integer.to_string(System.unique_integer([:positive]))
  end

  defp bind_instance(instance_id) do
    Mimic.set_mimic_private()

    Config
    |> Mimic.stub(:astarte_instance_id, fn -> {:ok, instance_id} end)
    |> Mimic.stub(:astarte_instance_id!, fn -> instance_id end)
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

  defp cleanup_keyspace(keyspace) do
    keyspace
    |> drop_keyspace_statement()
    |> Repo.query!()
  end

  defp drop_keyspace_statement(keyspace) do
    "DROP KEYSPACE IF EXISTS #{keyspace};"
  end
end
