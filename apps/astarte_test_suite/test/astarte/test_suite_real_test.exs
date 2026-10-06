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

defmodule Astarte.TestSuiteRealRealmContextTest do
  alias Astarte.DataAccess.Config

  use Astarte.TestSuite,
    instance: true,
    realm: [realm_names: ["realm1"]]

  @moduletag :integration
  describe "realm context" do
    test "loads deduced graph cases in order", %{
      astarte_test_suite_loaded_cases: loaded_cases
    } do
      assert loaded_cases == [:common, :instance, :realm]
    end

    test "writes common boot flag", %{common_booted?: common_booted?} do
      assert common_booted?
    end

    test "writes isolated instance into canonical graph context", %{
      instance_id: instance_id,
      instances: instances
    } do
      assert instances == %{instance_id => {instance_id, nil}}
    end

    test "writes explicit realm into canonical graph context", %{
      instance_id: instance_id,
      realms: realms
    } do
      assert realms == %{
               "realm1" =>
                 {%{id: "realm1", name: "realm1", instance_id: instance_id}, instance_id}
             }
    end

    test "binds the setup_all instance in the test process", %{instance_id: instance_id} do
      assert Config.astarte_instance_id!() == instance_id
    end
  end
end

defmodule Astarte.TestSuiteRealInterfaceContextTest do
  use Astarte.TestSuite,
    instance: true,
    interface: [interface_number: 1]

  @moduletag :integration
  describe "interface context" do
    test "loads interface ancestors in order", %{
      astarte_test_suite_loaded_cases: loaded_cases
    } do
      assert loaded_cases == [:common, :instance, :realm, :interface]
    end

    test "registers interface fixture state", %{interfaces_registered?: interfaces_registered?} do
      assert interfaces_registered?
    end

    test "stores generated interfaces in canonical graph context", %{interfaces: interfaces} do
      assert map_size(interfaces) == 1
    end

    test "records interface database work", %{interface_database_results: database_results} do
      assert length(database_results) == 1
    end
  end
end

defmodule Astarte.TestSuiteRealDeviceContextTest do
  use Astarte.TestSuite,
    instance: true,
    interface: [interface_number: 1],
    device: [device_number: 1]

  alias Astarte.DataAccess.Device, as: DeviceData
  alias Astarte.DataAccess.Realms.Realm, as: RealmData
  alias Astarte.DataAccess.Repo

  @moduletag :integration
  describe "device context" do
    test "persists the generated device", %{
      devices: devices,
      interfaces: interfaces,
      realms: realms
    } do
      [{_device_key, {%{device_id: device_id}, interface_id}}] = Map.to_list(devices)
      {_interface, realm_id} = Map.fetch!(interfaces, interface_id)
      {%{id: realm_name}, _instance_id} = Map.fetch!(realms, realm_id)

      %DeviceData{device_id: stored_device_id} =
        Repo.get!(DeviceData, device_id, prefix: RealmData.keyspace_name(realm_name))

      assert stored_device_id == device_id
    end
  end
end

defmodule Astarte.TestSuiteRealGroupContextTest do
  use Astarte.TestSuite,
    instance: true,
    interface: [interface_number: 1],
    device: [device_number: 1],
    group: [group_name: "test-group"]

  import Ecto.Query

  alias Astarte.DataAccess.Device, as: DeviceData
  alias Astarte.DataAccess.Groups.GroupedDevice
  alias Astarte.DataAccess.Realms.Realm, as: RealmData
  alias Astarte.DataAccess.Repo

  @moduletag :integration
  describe "group context" do
    test "persists the generated group", %{
      devices: devices,
      groups: groups,
      interfaces: interfaces,
      realms: realms
    } do
      [{_group_key, {%{device_ids: [device_id], name: group_name}, device_key}}] =
        Map.to_list(groups)

      {_device, interface_id} = Map.fetch!(devices, device_key)
      {_interface, realm_id} = Map.fetch!(interfaces, interface_id)
      {%{id: realm_name}, _instance_id} = Map.fetch!(realms, realm_id)
      keyspace = RealmData.keyspace_name(realm_name)

      %GroupedDevice{
        device_id: stored_device_id,
        group_name: stored_group_name,
        insertion_uuid: insertion_uuid
      } =
        from(grouped_device in GroupedDevice,
          where: grouped_device.group_name == ^group_name
        )
        |> Repo.one!(prefix: keyspace)

      %DeviceData{groups: stored_groups} = Repo.get!(DeviceData, device_id, prefix: keyspace)

      assert stored_group_name == group_name
      assert stored_device_id == device_id
      assert stored_groups[group_name] == insertion_uuid
    end
  end
end

defmodule Astarte.TestSuiteRealPolicyContextTest do
  use Astarte.TestSuite,
    instance: true,
    policy: [policy_number: 1]

  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProtobuf
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm, as: RealmData

  @moduletag :integration
  describe "policy context" do
    test "persists the generated policy", %{policies: policies, realms: realms} do
      [{_policy_id, {%Policy{name: name} = policy, realm_id}}] = Map.to_list(policies)
      {%{id: realm_name}, _instance_id} = Map.fetch!(realms, realm_id)

      assert {:ok, encoded_policy} =
               KvStore.fetch_value(
                 "trigger_policy",
                 name,
                 :binary,
                 prefix: RealmData.keyspace_name(realm_name)
               )

      assert encoded_policy == PolicyProtobuf.encode(Policy.to_policy_proto(policy))
    end
  end
end

defmodule Astarte.TestSuiteRealTriggerContextTest do
  use Astarte.TestSuite,
    instance: true,
    policy: true,
    trigger: [trigger_number: 1]

  alias Astarte.Core.Triggers.Trigger
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm, as: RealmData

  @moduletag :integration
  describe "trigger context" do
    test "persists the generated trigger and its indexes", %{
      realms: realms,
      triggers: triggers
    } do
      [{_trigger_id, {%Trigger{} = trigger, realm_id}}] = Map.to_list(triggers)
      %{name: name, policy: policy, trigger_uuid: trigger_uuid} = trigger
      {%{id: realm_name}, _instance_id} = Map.fetch!(realms, realm_id)
      prefix = RealmData.keyspace_name(realm_name)
      trigger_uuid_string = UUID.binary_to_string!(trigger_uuid)

      assert {:ok, encoded_trigger} =
               KvStore.fetch_value("triggers", trigger_uuid_string, :binary, prefix: prefix)

      assert {:ok, ^trigger_uuid} =
               KvStore.fetch_value("triggers-by-name", name, :uuid, prefix: prefix)

      assert {:ok, ^trigger_uuid} =
               KvStore.fetch_value(
                 "triggers-with-policy-#{policy}",
                 trigger_uuid_string,
                 :uuid,
                 prefix: prefix
               )

      assert {:ok, ^policy} =
               KvStore.fetch_value("trigger_to_policy", trigger_uuid_string, :binary,
                 prefix: prefix
               )

      assert encoded_trigger == Trigger.encode(trigger)
    end
  end
end

defmodule Astarte.TestSuiteRealSimpleTriggerContextTest do
  use Astarte.TestSuite,
    instance: true,
    simple_trigger: true

  import Ecto.Query

  import Astarte.DataAccess.Adapters.Triggers.SimpleTrigger,
    only: [from_core_simple_trigger_to_change: 1]

  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm, as: RealmData
  alias Astarte.DataAccess.Realms.SimpleTrigger, as: SimpleTriggerData
  alias Astarte.DataAccess.Repo

  @moduletag :integration
  describe "simple trigger context" do
    test "persists the generated simple trigger and its reference", %{
      realms: realms,
      simple_triggers: simple_triggers,
      triggers: triggers
    } do
      [{_simple_trigger_id, {source, trigger_id}}] = Map.to_list(simple_triggers)
      {_trigger, realm_id} = Map.fetch!(triggers, trigger_id)
      {%{id: realm_name}, _instance_id} = Map.fetch!(realms, realm_id)
      prefix = RealmData.keyspace_name(realm_name)

      %{
        simple_trigger: simple_trigger_changes,
        simple_trigger_reference: %{
          group: reference_group,
          key: reference_key,
          value: reference_value
        }
      } = from_core_simple_trigger_to_change(source)

      %{
        object_id: object_id,
        object_type: object_type,
        parent_trigger_id: parent_trigger_id,
        simple_trigger_id: simple_trigger_id
      } = simple_trigger_changes

      stored_simple_trigger =
        from(simple_trigger in SimpleTriggerData,
          where:
            simple_trigger.object_id == ^object_id and
              simple_trigger.object_type == ^object_type and
              simple_trigger.parent_trigger_id == ^parent_trigger_id and
              simple_trigger.simple_trigger_id == ^simple_trigger_id
        )
        |> Repo.one!(prefix: prefix)

      assert Map.take(stored_simple_trigger, Map.keys(simple_trigger_changes)) ==
               simple_trigger_changes

      assert {:ok, reference_value} ==
               KvStore.fetch_value(
                 reference_group,
                 reference_key,
                 :binary,
                 prefix: prefix
               )
    end
  end
end

defmodule Astarte.TestSuiteRealExternalCasesTest do
  use Astarte.TestSuite,
    instance: true,
    external_cases: [
      Astarte.TestSuiteTest.Cases.NoParamsCase,
      {Astarte.TestSuiteTest.Cases.ParamsCase, [value: 7]}
    ]

  @moduletag :integration
  describe "external cases" do
    test "applies external case without params", %{no_params_case?: no_params_case?} do
      assert no_params_case?
    end

    test "applies external case with params", %{params_case_value: params_case_value} do
      assert params_case_value == 7
    end
  end
end
