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

defmodule Astarte.TestSuite.Fixtures.RealmTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Fixtures.Instance, as: InstanceFixtures
  alias Astarte.TestSuite.Fixtures.Realm, as: RealmFixtures

  test "realm fixture handles empty realms" do
    {:ok, context} = RealmFixtures.data(%{realms: %{}})
    assert context.realms_ready?
  end

  @tag :integration
  test "realm fixture sets realms flag" do
    assert context().realms_ready?
  end

  defp context do
    realm_id = "realm" <> Integer.to_string(System.unique_integer([:positive]))

    {:ok, base} = InstanceFixtures.setup(%{})
    {:ok, base} = InstanceFixtures.data(base)

    base =
      Map.put(base, :realms, %{
        realm_id => {%{id: realm_id, instance_id: base.instance_id}, base.instance_id}
      })

    {:ok, context} = RealmFixtures.data(base)
    context
  end
end
