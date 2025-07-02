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

defmodule Astarte.RealmManagement.API.TriggersTest do
  use Astarte.Cases.Data, async: true
  use ExUnitProperties

  @moduletag :triggers

  alias Astarte.Helpers.Database
  alias Astarte.RealmManagement.API.Fixtures.SimpleTriggerConfig, as: SimpleTriggerConfigFixture
  alias Astarte.RealmManagement.API.Fixtures.Trigger, as: TriggerFixture
  alias Astarte.RealmManagement.API.Triggers
  alias Astarte.RealmManagement.API.Triggers.Core
  alias Astarte.RealmManagement.API.Triggers.Trigger
  alias Astarte.RealmManagement.API.Triggers.HttpAction
  alias Astarte.RealmManagement.API.Triggers.Action
  alias Astarte.RealmManagement.API.Triggers.Policies
  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator

  setup context do
    %{realm: realm, astarte_instance_id: astarte_instance_id} = context
    trigger_attrs = TriggerFixture.valid_trigger_attrs()
    trigger_name = trigger_attrs["name"]

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
