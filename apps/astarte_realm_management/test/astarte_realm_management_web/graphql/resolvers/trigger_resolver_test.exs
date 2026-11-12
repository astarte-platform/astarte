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

defmodule Astarte.RealmManagementWeb.GraphQL.Resolvers.TriggerResolverTest do
  use Astarte.RealmManagement.Cases.Data, async: true
  use Mimic

  alias Astarte.RealmManagement.Triggers
  alias Astarte.RealmManagementWeb.GraphQL.Resolvers.TriggerResolver

  @trigger_name "my_trigger"
  @valid_attrs %{
    "name" => @trigger_name,
    "action" => %{
      "http_post_url" => "http://www.example.com"
    },
    "simple_triggers" => [
      %{
        "type" => "data_trigger",
        "on" => "incoming_data",
        "interface_name" => "com.test.SimpleStreamTest",
        "interface_major" => 0,
        "match_path" => "/%{itemIndex}/value",
        "value_match_operator" => ">",
        "known_value" => 0.6
      }
    ]
  }

  @interface_attrs %{
    "interface_name" => "com.test.SimpleStreamTest",
    "version_major" => 0,
    "version_minor" => 1,
    "type" => "datastream",
    "ownership" => "device",
    "aggregation" => "individual",
    "mappings" => [
      %{
        "endpoint" => "/%{itemIndex}/value",
        "type" => "double",
        "explicit_timestamp" => true
      }
    ]
  }

  setup %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} do
    resolution = %{
      context: %{
        realm_name: realm_name
      }
    }

    on_exit(fn ->
      Astarte.RealmManagement.Helpers.Database.setup_database_access(astarte_instance_id)
      # Cleanup after tests
      try do
        with {:ok, trigger} <-
               Astarte.RealmManagement.Triggers.get_trigger(realm_name, @trigger_name) do
          Astarte.RealmManagement.Triggers.delete_trigger(realm_name, trigger)
        end
      rescue
        _ -> :ok
      end
    end)

    %{resolution: resolution, valid_attrs: @valid_attrs, interface_attrs: @interface_attrs}
  end

  describe "install_trigger/3" do
    setup %{realm_name: realm_name, interface_attrs: interface_attrs} do
      Astarte.RealmManagement.Interfaces.install_interface(realm_name, interface_attrs,
        async: false
      )

      :ok
    end

    test "installs a trigger successfully", %{resolution: resolution, valid_attrs: valid_attrs} do
      args = %{data: Map.put(valid_attrs, "name", "new_trigger")}

      assert {:ok, %{name: "new_trigger"}} =
               TriggerResolver.install_trigger(nil, args, resolution)
    end
  end

  describe "get_trigger/3" do
    setup %{realm_name: realm_name, valid_attrs: valid_attrs, interface_attrs: interface_attrs} do
      Astarte.RealmManagement.Interfaces.install_interface(realm_name, interface_attrs,
        async: false
      )

      Triggers.create_trigger(realm_name, valid_attrs)
      :ok
    end

    test "returns a trigger successfully", %{resolution: resolution} do
      args = %{trigger_name: @trigger_name}

      assert {:ok, %{name: @trigger_name}} = TriggerResolver.get_trigger(nil, args, resolution)
    end

    test "returns error if not found", %{resolution: resolution} do
      args = %{trigger_name: "invalid_trigger"}

      assert {:error, "Trigger not found"} = TriggerResolver.get_trigger(nil, args, resolution)
    end
  end

  describe "list_triggers/3" do
    setup %{realm_name: realm_name, valid_attrs: valid_attrs, interface_attrs: interface_attrs} do
      Astarte.RealmManagement.Interfaces.install_interface(realm_name, interface_attrs,
        async: false
      )

      Triggers.create_trigger(realm_name, valid_attrs)
      :ok
    end

    test "lists triggers successfully", %{resolution: resolution} do
      assert {:ok, names} = TriggerResolver.list_triggers(nil, %{}, resolution)
      assert Enum.member?(names, @trigger_name)
    end
  end

  describe "delete_trigger/3" do
    setup %{realm_name: realm_name, valid_attrs: valid_attrs, interface_attrs: interface_attrs} do
      Astarte.RealmManagement.Interfaces.install_interface(realm_name, interface_attrs,
        async: false
      )

      Triggers.create_trigger(realm_name, valid_attrs)
      :ok
    end

    test "deletes a trigger successfully", %{resolution: resolution} do
      args = %{trigger_name: @trigger_name}

      assert {:ok, "Trigger deleted successfully"} =
               TriggerResolver.delete_trigger(nil, args, resolution)
    end
  end

  describe "policies" do
    defp build_policy(name) do
      %{
        "name" => name,
        "maximum_capacity" => 100,
        "error_handlers" => [
          %{
            "on" => "any_error",
            "strategy" => "discard"
          }
        ]
      }
    end

    test "installs a policy successfully", %{resolution: resolution} do
      name = "my_policy_install"
      args = %{data: build_policy(name)}

      assert {:ok, %{name: ^name}} =
               TriggerResolver.install_policy(nil, args, resolution)
    end

    test "lists policies successfully", %{resolution: resolution} do
      name = "my_policy_list"
      TriggerResolver.install_policy(nil, %{data: build_policy(name)}, resolution)

      assert {:ok, names} = TriggerResolver.list_policies(nil, %{}, resolution)
      assert Enum.member?(names, name)
    end

    test "gets a policy successfully", %{resolution: resolution} do
      name = "my_policy_get"
      TriggerResolver.install_policy(nil, %{data: build_policy(name)}, resolution)
      args = %{policy_name: name}

      assert {:ok, policy} = TriggerResolver.get_policy(nil, args, resolution)
      assert policy["name"] == name
    end

    test "deletes a policy successfully", %{resolution: resolution} do
      name = "my_policy_delete"
      TriggerResolver.install_policy(nil, %{data: build_policy(name)}, resolution)
      args = %{policy_name: name}

      assert {:ok, "Trigger policy deleted successfully"} =
               TriggerResolver.delete_policy(nil, args, resolution)
    end
  end

  describe "missing context" do
    test "returns error when realm_name is missing" do
      resolution = %{context: %{}}

      assert {:error, "Missing realm context"} =
               TriggerResolver.list_triggers(nil, %{}, resolution)

      assert {:error, "Missing realm context"} = TriggerResolver.get_trigger(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               TriggerResolver.install_trigger(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               TriggerResolver.delete_trigger(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               TriggerResolver.list_policies(nil, %{}, resolution)

      assert {:error, "Missing realm context"} = TriggerResolver.get_policy(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               TriggerResolver.install_policy(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               TriggerResolver.delete_policy(nil, %{}, resolution)
    end
  end
end
