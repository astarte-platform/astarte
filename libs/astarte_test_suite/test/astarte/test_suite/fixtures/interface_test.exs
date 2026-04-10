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

defmodule Astarte.TestSuite.Fixtures.InterfaceTest do
  use ExUnit.Case, async: false

  import Astarte.Core.Generators.Interface, only: [interface: 0]

  import Astarte.TestSuite.CaseContext

  alias Astarte.TestSuite.Fixtures.Instance, as: InstanceFixtures
  alias Astarte.TestSuite.Fixtures.Interface, as: InterfaceFixtures
  alias Astarte.TestSuite.Fixtures.Realm, as: RealmFixtures

  test "interface fixture handles empty interfaces" do
    {:ok, context} = InterfaceFixtures.data(%{interfaces: %{}})
    assert context.interfaces_registered?
  end

  @tag :real_db
  test "interface fixture sets registration flag" do
    assert context().interfaces_registered?
  end

  defp context do
    instance_id = "astarte" <> Integer.to_string(System.unique_integer([:positive]))
    realm_id = "realm" <> Integer.to_string(System.unique_integer([:positive]))

    base =
      %{
        instance_cluster: :xandra,
        instances: %{instance_id => {instance_id, nil}},
        realms: %{realm_id => {%{id: realm_id, instance_id: instance_id}, instance_id}}
      }
      |> put!(:interfaces, core_interface().name, core_interface(), realm_id)

    {:ok, base} = InstanceFixtures.setup(base)
    {:ok, base} = InstanceFixtures.data(base)
    {:ok, base} = RealmFixtures.data(base)
    {:ok, context} = InterfaceFixtures.data(base)
    context
  end

  defp core_interface, do: interface() |> Enum.at(0)
end
