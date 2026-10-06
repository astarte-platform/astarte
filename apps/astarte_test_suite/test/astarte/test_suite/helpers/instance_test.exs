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

defmodule Astarte.TestSuite.Helpers.InstanceTest do
  use ExUnit.Case, async: true

  alias Astarte.DataAccess.Config
  alias Astarte.DataAccess.Database
  alias Astarte.TestSuite.Helpers.Instance, as: InstanceHelper

  describe "instance setup" do
    test "creates one canonical instance" do
      %{instance_id: instance_id} = context = InstanceHelper.setup(%{})

      assert context.instance_setup?
      assert context.instances == %{instance_id => {instance_id, nil}}
    end

    test "uses the unique instance in the data access configuration" do
      %{instance_id: instance_id} = InstanceHelper.setup(%{})

      assert Config.astarte_instance_id() == {:ok, instance_id}
      assert Config.astarte_instance_id!() == instance_id
    end

    test "binds the setup_all instance in another process" do
      %{instance_id: instance_id} = context = InstanceHelper.setup(%{})

      configured_instance =
        Task.async(fn ->
          InstanceHelper.bind(context)
          Config.astarte_instance_id!()
        end)
        |> Task.await()

      assert configured_instance == instance_id
    end
  end

  describe "instance database" do
    @tag :integration
    test "migrates the isolated astarte keyspace" do
      context = migrated_context()

      assert context.instance_database_ready?
      assert context.instance_keyspaces == [context.instance_keyspace]
      assert Database.astarte_initialized?()
    end

    @tag :integration
    test "records the astarte keyspace creation" do
      context = migrated_context()

      assert context.instance_database_statements == [
               "CREATE KEYSPACE IF NOT EXISTS #{context.instance_keyspace}\n  WITH\n  replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND\n  durable_writes = true;"
             ]
    end
  end

  defp migrated_context, do: %{} |> InstanceHelper.setup() |> InstanceHelper.data()
end
