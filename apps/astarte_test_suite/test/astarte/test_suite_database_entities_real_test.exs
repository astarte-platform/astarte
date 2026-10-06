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

defmodule Astarte.TestSuiteDatabaseEntitiesRealTest do
  use Astarte.TestSuite,
    interface: [interface_number: 1],
    group: [group_name: "test-suite-group"],
    policy: true,
    simple_trigger: true

  @moduletag :integration

  describe "database entity graph" do
    test "prepares all configured entity branches", %{
      astarte_test_suite_loaded_cases: loaded_cases,
      devices: devices,
      devices_registered?: devices_registered?,
      groups: groups,
      groups_ready?: groups_ready?,
      instance_database_ready?: instance_database_ready?,
      interfaces: interfaces,
      interfaces_registered?: interfaces_registered?,
      policies: policies,
      policies_registered?: policies_registered?,
      realms: realms,
      realms_ready?: realms_ready?,
      simple_triggers: simple_triggers,
      simple_triggers_registered?: simple_triggers_registered?,
      triggers: triggers,
      triggers_registered?: triggers_registered?
    } do
      assert loaded_cases == [
               :common,
               :instance,
               :realm,
               :interface,
               :device,
               :group,
               :policy,
               :trigger,
               :simple_trigger
             ]

      assert instance_database_ready?
      assert realms_ready?
      assert interfaces_registered?
      assert devices_registered?
      assert groups_ready?
      assert policies_registered?
      assert triggers_registered?
      assert simple_triggers_registered?
      assert map_size(realms) == 1
      assert map_size(interfaces) == 1
      assert map_size(devices) == 1
      assert map_size(groups) == 1
      assert map_size(policies) == 1
      assert map_size(triggers) == 1
      assert map_size(simple_triggers) == 1
    end
  end
end
