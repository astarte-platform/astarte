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
  use Astarte.RealmManagement.API.DataCase

  @moduletag :triggers

  alias Astarte.RealmManagement.API.Triggers
  alias Astarte.RealmManagement.API.Triggers.Trigger
  alias Astarte.RealmManagement.API.Triggers.Action
  alias Astarte.RealmManagement.API.Fixtures.Trigger, as: TriggerFixture

  @test_realm "test"

  describe "triggers" do
    test "create_trigger/1 with valid data creates a trigger" do
      trigger_attrs = TriggerFixture.valid_trigger_attrs()

      assert {:ok, installed_trigger} =
               Triggers.create_trigger(@test_realm, trigger_attrs)

      expected_action = trigger_attrs["action"]

      assert installed_trigger.name == trigger_attrs["name"]

      assert installed_trigger.action.http_method == expected_action["http_method"]
      assert installed_trigger.action.http_url == expected_action["http_url"]
      assert installed_trigger.action.ignore_ssl_errors == expected_action["ignore_ssl_errors"]

      assert simple_triggers_to_map(installed_trigger.simple_triggers) ==
               trigger_attrs["simple_triggers"]
    end

    test "create_trigger/1 with invalid data returns error changeset" do
      trigger_attrs = TriggerFixture.invalid_trigger_attrs()

      assert {:error, %Ecto.Changeset{}} = Triggers.create_trigger(@test_realm, trigger_attrs)
    end

    test "create_trigger/1 fails if trigger already exists" do
      trigger_attrs = TriggerFixture.valid_trigger_attrs()
      Triggers.create_trigger(@test_realm, trigger_attrs)

      assert {:error, :already_installed_trigger} =
               Triggers.create_trigger(@test_realm, trigger_attrs)
    end

    test "list_triggers/0 returns all triggers" do
      trigger_attrs = TriggerFixture.valid_trigger_attrs()

      assert {:ok, %Trigger{} = installed_trigger} =
               Triggers.create_trigger(@test_realm, trigger_attrs)

      assert Triggers.list_triggers(@test_realm) == [installed_trigger.name]
    end

    test "get_trigger/1 returns the trigger with given name" do
      trigger_attrs = TriggerFixture.valid_trigger_attrs()

      assert {:ok, %Trigger{} = installed_trigger} =
               Triggers.create_trigger(@test_realm, trigger_attrs)

      assert {:ok, installed_trigger} == Triggers.get_trigger(@test_realm, installed_trigger.name)
    end

    test "delete_trigger/1 deletes the trigger" do
      trigger_attrs = TriggerFixture.valid_trigger_attrs()

      assert {:ok, %Trigger{} = installed_trigger} =
               Triggers.create_trigger(@test_realm, trigger_attrs)

      assert {:ok, %Trigger{}} = Triggers.delete_trigger(@test_realm, installed_trigger)
    end

    test "delete_trigger/1 fails on an already deleted trigger" do
      trigger_attrs = TriggerFixture.valid_trigger_attrs()

      assert {:ok, %Trigger{} = trigger} =
               Triggers.create_trigger(@test_realm, trigger_attrs)

      assert {:ok, %Trigger{}} = Triggers.delete_trigger(@test_realm, trigger)
      assert {:error, :trigger_not_found} = Triggers.delete_trigger(@test_realm, trigger)
    end
  end

  defp simple_triggers_to_map(simple_triggers) do
    Enum.map(simple_triggers, fn st ->
      %{
        "type" => st.type,
        "device_id" => st.device_id,
        "on" => st.on,
        "interface_major" => st.interface_major
      }
    end)
  end
end
