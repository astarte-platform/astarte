#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.TriggersTest do
  use Astarte.Cases.Data, async: true
  use ExUnitProperties
  use Mimic

  @moduletag :triggers

  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Events.Triggers, as: EventsTriggers
  alias Astarte.Helpers.Database
  alias Astarte.RealmManagement.Fixtures.SimpleTriggerConfig, as: SimpleTriggerConfigFixture
  alias Astarte.RealmManagement.Fixtures.Trigger, as: TriggerFixture
  alias Astarte.RealmManagement.Triggers
  alias Astarte.RealmManagement.Triggers.Action
  alias Astarte.RealmManagement.Triggers.Core
  alias Astarte.RealmManagement.Triggers.HttpAction
  alias Astarte.RealmManagement.Triggers.Policies
  alias Astarte.RealmManagement.Triggers.Trigger
  alias Astarte.RPC.Triggers, as: RPCTriggers
  alias Astarte.RPC.Triggers.TriggerDeletion
  alias Astarte.RPC.Triggers.TriggerInstallation

  import Astarte.Helpers.Triggers

  setup :verify_on_exit!

  setup context do
    %{realm: realm, astarte_instance_id: astarte_instance_id} = context
    trigger_attrs = TriggerFixture.valid_trigger_attrs()
    trigger_name = trigger_attrs["name"]

    ignore_trigger_notifications()

    on_exit(fn ->
      Database.setup_database_access(astarte_instance_id)

      with {:ok, trigger} <- Triggers.get_trigger(realm, trigger_name) do
        Core.delete_trigger(realm, trigger)
      end
    end)

    %{trigger_attrs: trigger_attrs}
  end

  describe "triggers" do
    test "create_trigger/1 with valid data creates a trigger", context do
      %{realm: realm, trigger_attrs: trigger_attrs} = context

      assert {:ok, installed_trigger} =
               Triggers.create_trigger(realm, trigger_attrs)

      expected_action = trigger_attrs["action"]

      assert installed_trigger.name == trigger_attrs["name"]

      assert installed_trigger.action.http_method == expected_action["http_method"]
      assert installed_trigger.action.http_url == expected_action["http_url"]
      assert installed_trigger.action.ignore_ssl_errors == expected_action["ignore_ssl_errors"]

      expected_simple_triggers =
        simple_triggers_to_map(installed_trigger.simple_triggers)
        |> Enum.map(&Map.reject(&1, fn {_key, value} -> value == nil end))

      assert expected_simple_triggers ==
               trigger_attrs["simple_triggers"]
    end

    test "create_trigger/1 sends a trigger installation notification", context do
      %{realm: realm, trigger_attrs: trigger_attrs} = context
      RPCTriggers.subscribe_all()

      {:ok, installed_trigger} =
        Triggers.create_trigger(realm, trigger_attrs)

      [simple_trigger_config] = installed_trigger.simple_triggers
      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(simple_trigger_config)

      assert_receive %TriggerInstallation{realm_name: ^realm} = trigger_installation
      assert trigger_installation.policy == trigger_attrs["policy"]
      assert trigger_installation.simple_trigger == tagged_simple_trigger
      assert is_struct(trigger_installation.target, AMQPTriggerTarget)
    end

    test "create_trigger/1 with invalid data returns error changeset", context do
      %{realm: realm} = context
      trigger_attrs = TriggerFixture.invalid_trigger_attrs()

      assert {:error, %Ecto.Changeset{}} = Triggers.create_trigger(realm, trigger_attrs)
    end

    test "create_trigger/1 fails if trigger already exists", context do
      %{realm: realm, trigger_attrs: trigger_attrs} = context
      Triggers.create_trigger(realm, trigger_attrs)

      assert {:error, :already_installed_trigger} =
               Triggers.create_trigger(realm, trigger_attrs)
    end

    test "list_triggers/0 returns all triggers", context do
      %{realm: realm, trigger_attrs: trigger_attrs} = context

      assert {:ok, %Trigger{} = installed_trigger} =
               Triggers.create_trigger(realm, trigger_attrs)

      assert Triggers.list_triggers(realm) == [installed_trigger.name]
    end

    test "get_trigger/1 returns the trigger with given name", context do
      %{realm: realm, trigger_attrs: trigger_attrs} = context

      assert {:ok, %Trigger{} = installed_trigger} =
               Triggers.create_trigger(realm, trigger_attrs)

      assert {:ok, installed_trigger} == Triggers.get_trigger(realm, installed_trigger.name)
    end

    test "delete_trigger/1 deletes the trigger", context do
      %{realm: realm, trigger_attrs: trigger_attrs} = context

      assert {:ok, %Trigger{} = installed_trigger} =
               Triggers.create_trigger(realm, trigger_attrs)

      assert {:ok, %Trigger{}} = Triggers.delete_trigger(realm, installed_trigger)
    end

    test "delete_trigger/1 sends a trigger deletion notification", context do
      %{realm: realm, trigger_attrs: trigger_attrs} = context

      {:ok, %Trigger{} = installed_trigger} = Triggers.create_trigger(realm, trigger_attrs)
      RPCTriggers.subscribe_all()
      [trigger_id] = installed_trigger.simple_triggers_uuids
      [simple_trigger_config] = installed_trigger.simple_triggers
      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(simple_trigger_config)

      {:ok, %Trigger{}} = Triggers.delete_trigger(realm, installed_trigger)

      assert_receive %TriggerDeletion{realm_name: ^realm} = deletion_notification
      assert deletion_notification.trigger_id == trigger_id
      assert deletion_notification.simple_trigger == tagged_simple_trigger
    end

    test "delete_trigger/1 fails on an already deleted trigger", context do
      %{realm: realm, trigger_attrs: trigger_attrs} = context

      assert {:ok, %Trigger{} = trigger} =
               Triggers.create_trigger(realm, trigger_attrs)

      assert {:ok, %Trigger{}} = Triggers.delete_trigger(realm, trigger)
      assert {:error, :trigger_not_found} = Triggers.delete_trigger(realm, trigger)
    end

    test "get_triggers_list/1 returns all triggers", context do
      %{realm: realm, trigger_attrs: trigger_attrs} = context

      assert {:ok, %Trigger{} = installed_trigger} =
               Triggers.create_trigger(realm, trigger_attrs)

      assert Triggers.list_triggers(realm) == [installed_trigger.name]
    end
  end

  describe "Test triggers" do
    @describetag :triggers

    @tag :creation
    property "are installed correctly", %{realm: realm} do
      check all device <- Astarte.Core.Generators.Device.device(),
                trigger <- trigger(string(:utf8, min_length: 1)),
                policy <- PolicyGenerator.policy() |> PolicyGenerator.to_changes(),
                simple_trigger <- simple_trigger_config(device.device_id) do
        {:ok, policy} = Policies.create_trigger_policy(realm, policy)

        _ = Jason.decode!(trigger.action, keys: :atoms)

        expected_action =
          %HttpAction{}
          |> HttpAction.changeset(Jason.decode!(trigger.action))
          |> Ecto.Changeset.apply_changes()
          |> Map.from_struct()
          |> Map.reject(fn {_key, value} -> value == nil end)

        expected_action =
          %Action{}
          |> Ecto.Changeset.change(expected_action)
          |> Ecto.Changeset.apply_changes()

        attrs = %{
          "name" => trigger.name,
          "policy" => policy.name,
          "action" => Jason.decode!(trigger.action),
          "simple_triggers" => simple_triggers_to_map([simple_trigger])
        }

        {:ok, rm_trigger} = Triggers.create_trigger(realm, attrs)

        {:ok, fetched_trigger} = Triggers.get_trigger(realm, trigger.name)

        assert expected_action == fetched_trigger.action
        assert trigger.name == fetched_trigger.name
        assert policy.name == fetched_trigger.policy

        simple_trigger =
          unless simple_trigger.interface_major,
            do: Map.put(simple_trigger, :interface_major, 0),
            else: simple_trigger

        assert fetched_trigger.simple_triggers == [simple_trigger]

        Triggers.delete_trigger(realm, rm_trigger)
        Policies.delete_trigger_policy(realm, policy.name)
      end
    end

    @tag :deletion
    property "are deleted correctly", %{realm: realm} do
      check all device <- Astarte.Core.Generators.Device.device(),
                trigger <- trigger(string(:utf8, min_length: 1)),
                simple_trigger <- simple_trigger_config(device.device_id) do
        attrs = %{
          name: trigger.name,
          policy: nil,
          action: trigger.action,
          simple_triggers: simple_triggers_to_map([simple_trigger])
        }

        {:ok, trigger} = Triggers.create_trigger(realm, attrs)

        assert {:ok, ^trigger} = Triggers.delete_trigger(realm, trigger)
        assert {:error, :trigger_not_found} = Triggers.get_trigger(realm, trigger.name)
      end
    end

    test "properly notify installation and deletion of triggers", context do
      %{realm: realm, trigger_attrs: trigger_attrs, astarte_instance_id: astarte_instance_id} =
        context

      # realm management receives device_deletion_started notifications
      trigger_attrs =
        Enum.into(
          %{
            "simple_triggers" => [
              %{"on" => "device_deletion_started", "type" => "device_trigger"}
            ]
          },
          trigger_attrs
        )

      device_id = Astarte.Core.Device.random_device_id()
      installation_ref = trigger_notification_installation_ref(astarte_instance_id, realm)
      deletion_ref = trigger_notification_deletion_ref(astarte_instance_id, realm)

      [] = get_triggers(realm, device_id)
      {:ok, trigger} = Triggers.create_trigger(realm, trigger_attrs)
      assert_receive ^installation_ref
      assert [_target] = get_triggers(realm, device_id)
      {:ok, _trigger} = Triggers.delete_trigger(realm, trigger)
      assert_receive ^deletion_ref
      assert [] = get_triggers(realm, device_id)
    end
  end

  defp get_triggers(realm, device_id) do
    EventsTriggers.find_device_trigger_targets(realm, device_id, [], :on_device_deletion_started)
  end

  defp trigger_notification_installation_ref(astarte_instance_id, realm_name) do
    id = System.unique_integer()
    ref = {:trigger_installed, id}
    test_process = self()

    EventsTriggers
    |> expect(:install_trigger, fn
      ^realm_name, simple_trigger, target, policy, data ->
        Database.setup_database_access(astarte_instance_id)

        res =
          Mimic.call_original(EventsTriggers, :install_trigger, [
            realm_name,
            simple_trigger,
            target,
            policy,
            data
          ])

        send(test_process, ref)
        res
    end)
    |> allow(test_process, rpc_trigger_client())

    ref
  end

  defp trigger_notification_deletion_ref(astarte_instance_id, realm_name) do
    id = System.unique_integer()
    ref = {:trigger_deleted, id}
    test_process = self()

    EventsTriggers
    |> expect(:delete_trigger, fn
      ^realm_name, trigger_id, simple_trigger, data ->
        Database.setup_database_access(astarte_instance_id)

        res =
          Mimic.call_original(EventsTriggers, :delete_trigger, [
            realm_name,
            trigger_id,
            simple_trigger,
            data
          ])

        send(test_process, ref)
        res
    end)
    |> allow(test_process, rpc_trigger_client())

    ref
  end

  defp ignore_trigger_notifications do
    EventsTriggers
    |> stub(:install_trigger, fn _, _, _, _, _ -> :ok end)
    |> stub(:delete_trigger, fn _, _, _, _ -> :ok end)
    |> allow(self(), rpc_trigger_client())
  end

  defp simple_triggers_to_map(simple_triggers) do
    Enum.map(simple_triggers, fn st ->
      %{
        "type" => st.type,
        "device_id" => st.device_id,
        "group_name" => st.group_name,
        "on" => st.on,
        "match_path" => st.match_path,
        "value_match_operator" => st.value_match_operator,
        "interface_name" => st.interface_name,
        "interface_major" => st.interface_major
      }
    end)
  end

  # Custom generators
  # TODO remove once `astarte_generators` implements generators for triggers
  defp trigger(name_gen), do: member_of(TriggerFixture.triggers(name_gen))

  defp simple_trigger_config(device_id),
    do: member_of(SimpleTriggerConfigFixture.simple_trigger_configs(device_id))
end
