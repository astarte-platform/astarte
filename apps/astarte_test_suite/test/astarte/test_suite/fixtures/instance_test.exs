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

defmodule Astarte.TestSuite.Fixtures.InstanceTest do
  use ExUnit.Case, async: true

  alias Astarte.DataAccess.Config
  alias Astarte.DataAccess.Database
  alias Astarte.TestSuite.Fixtures.Instance, as: InstanceFixtures

  describe "instance fixture" do
    test "passes setup data through the instance helper" do
      {:ok, %{instance_id: instance_id} = context} = InstanceFixtures.setup(%{})

      assert context.instance_setup?
      assert context.instances == %{instance_id => {instance_id, nil}}
    end

    test "binds the setup process instance in another process" do
      {:ok, %{instance_id: instance_id} = context} = InstanceFixtures.setup(%{})

      configured_instance =
        Task.async(fn ->
          :ok = InstanceFixtures.bind(context)
          Config.astarte_instance_id!()
        end)
        |> Task.await()

      assert configured_instance == instance_id
    end

    @tag :integration
    test "passes migrated database data through the instance helper" do
      {:ok, context} = InstanceFixtures.setup(%{})
      {:ok, context} = InstanceFixtures.data(context)

      assert context.instance_database_ready?
      assert Database.astarte_initialized?()
    end
  end
end
