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
  test "loads deduced graph cases in order", context do
    assert context.astarte_test_suite_loaded_cases == [:common, :instance, :realm]
  end

  test "writes common boot flag", context do
    assert context.common_booted?
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
             "realm1" => {%{id: "realm1", name: "realm1", instance_id: instance_id}, instance_id}
           }
  end

  test "binds the setup_all instance in the test process", %{instance_id: instance_id} do
    assert Config.astarte_instance_id!() == instance_id
  end
end

defmodule Astarte.TestSuiteRealInterfaceContextTest do
  use Astarte.TestSuite,
    instance: true,
    interface: [interface_number: 1]

  @moduletag :integration
  test "loads interface ancestors in order", context do
    assert context.astarte_test_suite_loaded_cases == [:common, :instance, :realm, :interface]
  end

  test "registers interface fixture state", context do
    assert context.interfaces_registered?
  end

  test "stores generated interfaces in canonical graph context", context do
    assert map_size(context.interfaces) == 1
  end

  test "records interface database work", context do
    assert length(context.interface_database_results) == 1
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
  test "persists the generated device", %{
    devices: devices,
    interfaces: interfaces,
    realms: realms
  } do
    [{_device_key, {%{device_id: device_id}, interface_id}}] = Map.to_list(devices)
    {_interface, realm_id} = Map.fetch!(interfaces, interface_id)
    {%{id: realm_name}, _instance_id} = Map.fetch!(realms, realm_id)

    device = Repo.get!(DeviceData, device_id, prefix: RealmData.keyspace_name(realm_name))

    assert device.device_id == device_id
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

    grouped_device =
      from(grouped_device in GroupedDevice,
        where: grouped_device.group_name == ^group_name
      )
      |> Repo.one!(prefix: keyspace)

    device = Repo.get!(DeviceData, device_id, prefix: keyspace)

    assert grouped_device.group_name == group_name
    assert grouped_device.device_id == device_id
    assert device.groups[group_name] == grouped_device.insertion_uuid
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

defmodule Astarte.TestSuiteRealExternalCasesTest do
  use Astarte.TestSuite,
    instance: true,
    external_cases: [
      Astarte.TestSuiteTest.Cases.NoParamsCase,
      {Astarte.TestSuiteTest.Cases.ParamsCase, [value: 7]}
    ]

  @moduletag :integration
  test "applies external case without params", context do
    assert context.no_params_case?
  end

  test "applies external case with params", context do
    assert context.params_case_value == 7
  end
end
