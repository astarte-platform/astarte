# This file is part of Astarte.
#
# Copyright 2026 - 2026 Clea Srl
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

defmodule Astarte.DataAccess.Realms.RealmTest do
  use Astarte.DataAccess.Cases.Database, async: true

  @moduletag :integration

  alias Astarte.Core.CQLUtils
  alias Astarte.DataAccess.Realms.Realm

  describe "keyspace_name/1 and keyspace_name/2" do
    test "returns the keyspace name for valid realms", %{
      astarte_instance_id: astarte_instance_id,
      realm_name: realm_name
    } do
      expected_keyspace_name =
        CQLUtils.realm_name_to_keyspace_name(realm_name, astarte_instance_id)

      assert Realm.keyspace_name(realm_name) == expected_keyspace_name
      assert Realm.keyspace_name(realm_name, astarte_instance_id) == expected_keyspace_name
    end

    test "raises for invalid realm names" do
      assert_raise ArgumentError, fn ->
        Realm.keyspace_name("astarte")
      end
    end
  end

  describe "astarte_keyspace_name/0 and astarte_keyspace_name/1" do
    test "returns the astarte keyspace name", %{astarte_instance_id: astarte_instance_id} do
      expected_keyspace_name =
        CQLUtils.realm_name_to_keyspace_name("astarte", astarte_instance_id)

      assert Realm.astarte_keyspace_name() == expected_keyspace_name
      assert Realm.astarte_keyspace_name(astarte_instance_id) == expected_keyspace_name
    end
  end

  describe "list_realm_names/0 and list_realm_names/1" do
    test "returns the list of realm names", %{
      astarte_instance_id: astarte_instance_id,
      realm_name: realm_name
    } do
      expected_realms = [realm_name]

      assert Realm.list_realm_names() == expected_realms
      assert Realm.list_realm_names(astarte_instance_id) == expected_realms
    end
  end
end
