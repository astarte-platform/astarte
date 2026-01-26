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

defmodule Astarte.Events.Triggers.QueriesTests do
  use Astarte.Cases.Data, async: true

  import Mimic

  alias Astarte.Events.Triggers.Queries
  alias Astarte.Core.Generators.Device, as: DeviceGenerator

  setup :verify_on_exit!

  describe "retrieve_policy_name/2" do
    setup context do
      %{realm_name: realm_name} = context

      custom_policy = "custom_policy_#{System.unique_integer([:positive])}"

      simple_trigger = install_simple_trigger(realm_name)

      install_trigger_policy_link(realm_name, simple_trigger.simple_trigger_id, custom_policy)

      {:ok, realm_name: realm_name, simple_trigger: simple_trigger, custom_policy: custom_policy}
    end

    test "returns policy name for existing trigger", %{
      realm_name: realm,
      simple_trigger: simple_trigger,
      custom_policy: custom_policy
    } do
      {:ok, policy} = Queries.retrieve_policy_name(realm, simple_trigger.simple_trigger_id)

      assert custom_policy == policy
    end
  end

  describe "get_policy_name/2" do
    setup context do
      %{realm_name: realm_name} = context

      custom_policy = "custom_policy_#{System.unique_integer([:positive])}"

      simple_trigger = install_simple_trigger(realm_name)

      install_trigger_policy_link(realm_name, simple_trigger.simple_trigger_id, custom_policy)

      {:ok, realm_name: realm_name, simple_trigger: simple_trigger, custom_policy: custom_policy}
    end

    test "returns policy name for existing trigger", %{
      realm_name: realm,
      simple_trigger: simple_trigger,
      custom_policy: custom_policy
    } do
      policy = Queries.get_policy_name(realm, simple_trigger.simple_trigger_id)

      assert custom_policy == policy
    end
  end

  describe "get_policy_name_map/2" do
    setup context do
      %{realm_name: realm_name} = context

      custom_policy = "custom_policy_#{System.unique_integer([:positive])}"

      simple_trigger = install_simple_trigger(realm_name)

      install_trigger_policy_link(realm_name, simple_trigger.simple_trigger_id, custom_policy)

      {:ok, realm_name: realm_name, simple_trigger: simple_trigger, custom_policy: custom_policy}
    end

    test "returns map with policy name for existing trigger", %{
      realm_name: realm,
      simple_trigger: simple_trigger,
      custom_policy: custom_policy
    } do
      policy = Queries.get_policy_name_map(realm, [simple_trigger.simple_trigger_id])

      assert %{simple_trigger.simple_trigger_id => custom_policy} == policy
    end
  end

  describe "get_device_groups/2" do
    setup context do
      %{realm_name: realm_name} = context

      device_id = DeviceGenerator.id() |> Enum.at(0)
      groups = ["group1", "group2", "group3"]

      {:ok, device} = insert_device(device_id, realm_name, groups: groups)
      {:ok, realm_name: realm_name, device: device, groups: groups}
    end

    test "returns groups for existing device", %{
      realm_name: realm,
      device: device,
      groups: expected_groups
    } do
      result = Queries.get_device_groups(realm, device.device_id)

      assert expected_groups == result
    end
  end

  describe "query_simple_triggers!/3" do
    setup context do
      %{realm_name: realm_name} = context

      simple_trigger = install_simple_trigger(realm_name)

      {:ok, realm_name: realm_name, simple_trigger: simple_trigger}
    end

    test "returns existing trigger", %{
      realm_name: realm,
      simple_trigger: expected_simple_trigger
    } do
      triggers =
        Queries.query_simple_triggers!(
          realm,
          expected_simple_trigger.object_id,
          expected_simple_trigger.object_type
        )

      assert Enum.any?(triggers, fn trigger ->
               trigger == expected_simple_trigger
             end)
    end
  end
end
