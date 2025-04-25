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

  describe "triggers" do
    alias Astarte.RealmManagement.API.Triggers.Trigger

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def trigger_fixture(attrs \\ %{}) do
      trigger_attrs =
        attrs
        |> Enum.into(@valid_attrs)

      {:ok, trigger} = RealmManagement.API.Triggers.create_trigger("test", trigger_attrs)

      trigger
    end

    @tag :wip
    test "list_triggers/0 returns all triggers" do
      trigger = trigger_fixture()
      assert RealmManagement.API.Triggers.list_triggers() == [trigger]
    end

    @tag :wip
    test "get_trigger!/1 returns the trigger with given id" do
      trigger = trigger_fixture()
      assert RealmManagement.API.Triggers.get_trigger!(trigger.id) == trigger
    end

    @tag :wip
    test "create_trigger/1 with valid data creates a trigger" do
      assert {:ok, %Trigger{} = trigger} =
               RealmManagement.API.Triggers.create_trigger(@valid_attrs)
    end

    @tag :wip
    test "create_trigger/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               RealmManagement.API.Triggers.create_trigger(@invalid_attrs)
    end

    @tag :wip
    test "delete_trigger/1 deletes the trigger" do
      trigger = trigger_fixture()
      assert {:ok, %Trigger{}} = RealmManagement.API.Triggers.delete_trigger(trigger)

      assert_raise Ecto.NoResultsError, fn ->
        RealmManagement.API.Triggers.get_trigger!(trigger.id)
      end
    end
  end
end
