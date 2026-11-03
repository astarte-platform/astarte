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

defmodule Astarte.Auth.AuthorizationModelTest do
  use Astarte.Auth.Cases.AuthorizationModel, async: true

  alias Astarte.Auth.OpenFGA

  @tuples [
    {"cluster:astarte", "parent", "realm:testrealm"},
    {"cluster:astarte", "parent", "realm:otherrealm"},
    {"realm:testrealm", "realm", "device_group:testrealm/line4"},
    {"realm:testrealm", "realm", "device:testrealm/dev1"},
    {"realm:testrealm", "realm", "device:testrealm/dev2"},
    {"device_group:testrealm/line4", "group", "device:testrealm/dev1"},
    {"realm:testrealm", "realm", "interface:testrealm/com.my.Commands"},
    {"realm:testrealm", "realm", "interface:testrealm/com.my.Telemetry"},
    {"realm:testrealm", "realm", "trigger:testrealm/connection"},
    {"realm:testrealm", "realm", "trigger_policy:testrealm/retry"},
    {"realm:otherrealm", "realm", "device:otherrealm/dev1"},
    {"user:_cluster/cluster_admin", "admin", "cluster:astarte"},
    {"user:testrealm/realm_admin", "admin", "realm:testrealm"},
    {"user:testrealm/fleet_manager", "fleet_manager", "realm:testrealm"},
    {"user:testrealm/line4_writer", "data_writer", "device_group:testrealm/line4"},
    {"user:testrealm/interface_writer", "data_writer", "interface:testrealm/com.my.Commands"},
    {"user:testrealm/fdo_viewer", "fdo_viewer", "realm:testrealm"},
    {"team:outer_team#member", "observer", "realm:testrealm"},
    {"team:inner_team#member", "member", "team:outer_team"},
    {"user:testrealm/nested_team_member", "member", "team:inner_team"}
  ]

  setup_all %{store_id: store_id} do
    tuples =
      Enum.map(@tuples, fn {user, relation, object} ->
        %{user: user, relation: relation, object: object}
      end)

    write_tuples!(store_id, tuples)
  end

  test "a realm administrator gets every realm capability except the cluster's" do
    assert_relations("user:testrealm/realm_admin", "realm:testrealm", %{
      can_read_realm: true,
      can_read_realm_config: true,
      can_update_realm_config: true,
      can_install_interface: true,
      can_create_trigger: true,
      can_create_trigger_policy: true,
      can_register_device: true,
      can_list_devices: true,
      can_create_device_group: true,
      can_manage_fdo: true,
      can_read_fdo: true,
      can_join_room: true,
      # only cluster admins
      can_update_realm: false,
      can_delete_realm: false
    })
  end

  test "replacing the realm public key is admin only, never another role" do
    assert_relations("user:testrealm/fleet_manager", "realm:testrealm", %{
      can_update_realm_config: false,
      can_read_realm_config: false
    })

    assert_relations("user:testrealm/nested_team_member", "realm:testrealm", %{
      can_read_realm_config: true,
      can_update_realm_config: false
    })

    assert_relations("user:testrealm/line4_writer", "realm:testrealm", %{
      can_update_realm_config: false
    })
  end

  test "erasing a device is admin only, unregistering it is the fleet manager's" do
    assert_relations("user:testrealm/fleet_manager", "device:testrealm/dev1", %{
      can_unregister: true,
      can_update: true,
      can_read: true,
      # deleting a device erases its data
      can_delete: false
    })

    assert_relations("user:testrealm/realm_admin", "device:testrealm/dev1", %{
      can_delete: true,
      can_unregister: true
    })
  end

  test "a cluster administrator inherits into every realm, and owns the realm lifecycle" do
    assert_relations("user:_cluster/cluster_admin", "cluster:astarte", %{
      can_create_realm: true,
      can_list_realms: true,
      can_read_cluster_config: true
    })

    assert_relations("user:_cluster/cluster_admin", "realm:testrealm", %{
      can_update_realm: true,
      can_delete_realm: true,
      can_update_realm_config: true,
      can_register_device: true
    })

    assert_relations("user:_cluster/cluster_admin", "realm:otherrealm", %{
      can_delete_realm: true,
      can_read_realm: true
    })
  end

  test "a device group grant scopes a user to that slice of the fleet only" do
    assert_relations("user:testrealm/line4_writer", "device:testrealm/dev1", %{
      can_write_data: true,
      can_read_data: true,
      can_read: true
    })

    assert_relations("user:testrealm/line4_writer", "device:testrealm/dev2", %{
      can_write_data: false,
      can_read_data: false,
      can_read: false
    })

    assert_relations("user:testrealm/line4_writer", "device_group:testrealm/line4", %{
      can_read: true,
      can_update: false
    })
  end

  test "an interface grant scopes a user to that interface only" do
    assert_relations("user:testrealm/interface_writer", "interface:testrealm/com.my.Commands", %{
      can_write_data: true,
      can_read_data: true,
      can_read: true,
      can_update: false,
      can_delete: false
    })

    assert_relations("user:testrealm/interface_writer", "interface:testrealm/com.my.Telemetry", %{
      can_write_data: false,
      can_read_data: false
    })
  end

  test "the two checks that gate data access are independent" do
    assert_relations("user:testrealm/interface_writer", "device:testrealm/dev1", %{
      can_write_data: false
    })

    assert_relations("user:testrealm/line4_writer", "interface:testrealm/com.my.Commands", %{
      can_write_data: false
    })
  end

  test "team membership nests, and grants the team's role" do
    assert_relations("user:testrealm/nested_team_member", "realm:testrealm", %{
      can_read_realm: true,
      can_list_interfaces: true,
      can_list_triggers: true,
      can_list_devices: true,
      can_read_stats: true,
      can_join_room: true,
      can_install_interface: false,
      can_create_trigger: false,
      can_register_device: false,
      can_create_device_group: false
    })

    assert_relations("user:testrealm/nested_team_member", "device:testrealm/dev1", %{
      can_read: true,
      can_read_data: true,
      can_write_data: false,
      can_unregister: false,
      can_delete: false
    })
  end

  test "writing data implies reading it, but reading never implies writing" do
    assert_relations("user:testrealm/line4_writer", "device:testrealm/dev1", %{
      can_write_data: true,
      can_read_data: true
    })

    assert_relations("user:testrealm/nested_team_member", "device:testrealm/dev1", %{
      can_read_data: true,
      can_write_data: false
    })
  end

  test "fdo_manager implies fdo_viewer, and the reverse never holds" do
    assert_relations("user:testrealm/fdo_viewer", "realm:testrealm", %{
      can_read_fdo: true,
      can_manage_fdo: false
    })

    assert_relations("user:testrealm/realm_admin", "realm:testrealm", %{
      can_read_fdo: true,
      can_manage_fdo: true
    })
  end

  test "grants never cross realms, even for an identical device id" do
    assert_relations("user:testrealm/realm_admin", "realm:otherrealm", %{
      can_read_realm: false,
      can_register_device: false,
      can_update_realm_config: false
    })

    assert_relations("user:testrealm/realm_admin", "device:otherrealm/dev1", %{
      can_read: false,
      can_delete: false,
      can_unregister: false
    })

    assert_relations("user:testrealm/line4_writer", "device:otherrealm/dev1", %{
      can_write_data: false
    })
  end

  test "a user with no tuples can do nothing" do
    assert_relations("user:testrealm/user_without_grants", "realm:testrealm", %{
      can_read_realm: false,
      can_read_realm_config: false,
      can_list_devices: false,
      can_register_device: false,
      can_read_fdo: false,
      can_join_room: false
    })

    assert_relations("user:testrealm/user_without_grants", "device:testrealm/dev1", %{
      can_read: false,
      can_read_data: false,
      can_write_data: false,
      can_unregister: false
    })

    assert_relations("user:testrealm/user_without_grants", "cluster:astarte", %{
      can_create_realm: false,
      can_list_realms: false
    })
  end

  test "triggers and policies follow the realm's roles" do
    assert_relations("user:testrealm/nested_team_member", "trigger:testrealm/connection", %{
      can_read: true,
      can_delete: false
    })

    assert_relations("user:testrealm/realm_admin", "trigger:testrealm/connection", %{
      can_read: true,
      can_delete: true
    })

    assert_relations("user:testrealm/nested_team_member", "trigger_policy:testrealm/retry", %{
      can_read: true,
      can_delete: false
    })

    assert_relations("user:testrealm/fleet_manager", "trigger:testrealm/connection", %{
      can_read: false,
      can_delete: false
    })
  end

  # assert on all relations at once so a failure lists all of them
  defp assert_relations(user, object, expected) do
    actual =
      Map.new(expected, fn {relation, _allowed} ->
        {relation, allowed?(user, relation, object)}
      end)

    assert actual == expected, "unexpected relations for #{user} on #{object}"
  end

  defp allowed?(user, relation, object) do
    case OpenFGA.check(user, Atom.to_string(relation), object) do
      :ok -> true
      {:error, :forbidden} -> false
    end
  end
end
