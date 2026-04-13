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

defmodule Astarte.TestSuite.Fixtures.InstanceTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Fixtures.Instance, as: InstanceFixtures

  test "instance fixture sets setup flag" do
    {:ok, context} = InstanceFixtures.setup(%{})
    assert context.instance_setup?
  end

  test "instance fixture handles empty instances" do
    {:ok, context} = InstanceFixtures.data(%{instances: %{}})
    assert context.instance_database_ready?
  end

  @tag :real_db
  test "instance fixture sets database flag" do
    assert context().instance_database_ready?
  end

  defp context do
    instance_id = "astarte" <> Integer.to_string(System.unique_integer([:positive]))

    base = %{
      instance_cluster: :xandra,
      instances: %{instance_id => {instance_id, nil}}
    }

    {:ok, context} = InstanceFixtures.setup(base)
    {:ok, context} = InstanceFixtures.data(context)
    context
  end
end
