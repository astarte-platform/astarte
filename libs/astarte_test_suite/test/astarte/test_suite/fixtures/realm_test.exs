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

defmodule Astarte.TestSuite.Fixtures.RealmTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Fixtures.Instance, as: InstanceFixtures
  alias Astarte.TestSuite.Fixtures.Realm, as: RealmFixtures

  test "realm fixture handles empty realms" do
    {:ok, context} = RealmFixtures.data(%{realms: %{}})
    assert context.realms_ready?
  end

  @tag :real_db
  test "realm fixture sets realms flag" do
    assert context().realms_ready?
  end

  defp context do
    instance_id = "astarte" <> Integer.to_string(System.unique_integer([:positive]))
    realm_id = "realm" <> Integer.to_string(System.unique_integer([:positive]))

    base = %{
      instance_cluster: :xandra,
      instances: %{instance_id => {instance_id, nil}},
      instance_database_ready?: true,
      realms: %{realm_id => {%{id: realm_id, instance_id: instance_id}, instance_id}}
    }

    {:ok, base} = InstanceFixtures.setup(base)
    {:ok, base} = InstanceFixtures.data(base)
    {:ok, context} = RealmFixtures.data(base)
    context
  end
end
