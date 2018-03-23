#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.API.TriggersTest do
  use Astarte.RealmManagement.API.DataCase

  alias Astarte.RealmManagement.API.Triggers

  describe "triggers" do
    alias Astarte.RealmManagement.API.Triggers.Trigger

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def trigger_fixture(attrs \\ %{}) do
      {:ok, trigger} =
        attrs
        |> Enum.into(@valid_attrs)
        |> RealmManagement.API.Triggers.create_trigger()

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
    test "update_trigger/2 with valid data updates the trigger" do
      trigger = trigger_fixture()
      assert {:ok, trigger} = RealmManagement.API.Triggers.update_trigger(trigger, @update_attrs)
      assert %Trigger{} = trigger
    end

    @tag :wip
    test "update_trigger/2 with invalid data returns error changeset" do
      trigger = trigger_fixture()

      assert {:error, %Ecto.Changeset{}} =
               RealmManagement.API.Triggers.update_trigger(trigger, @invalid_attrs)

      assert trigger == RealmManagement.API.Triggers.get_trigger!(trigger.id)
    end

    @tag :wip
    test "delete_trigger/1 deletes the trigger" do
      trigger = trigger_fixture()
      assert {:ok, %Trigger{}} = RealmManagement.API.Triggers.delete_trigger(trigger)

      assert_raise Ecto.NoResultsError, fn ->
        RealmManagement.API.Triggers.get_trigger!(trigger.id)
      end
    end

    @tag :wip
    test "change_trigger/1 returns a trigger changeset" do
      trigger = trigger_fixture()
      assert %Ecto.Changeset{} = RealmManagement.API.Triggers.change_trigger(trigger)
    end
  end
end
