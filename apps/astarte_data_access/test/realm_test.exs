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

defmodule Astarte.DataAccess.Realms.RealmTest do
  use Astarte.DataAccess.Cases.Database, async: true
  alias Astarte.Core.CQLUtils
  alias Astarte.DataAccess.Realms.Realm

  describe "keyspace_name/1" do
    test "returns the keyspace name for valid realms", context do
      %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} = context

      expected_keyspace_name =
        CQLUtils.realm_name_to_keyspace_name(realm_name, astarte_instance_id)

      assert Realm.keyspace_name(realm_name) == expected_keyspace_name
    end

    test "raises for invalid realm names" do
      assert_raise ArgumentError, fn ->
        Realm.keyspace_name("astarte")
      end
    end
  end

  describe "asarte_keyspace_name/0" do
    test "returns the astarte keyspace name", context do
      %{astarte_instance_id: astarte_instance_id} = context

      expected_keyspace_name =
        CQLUtils.realm_name_to_keyspace_name("astarte", astarte_instance_id)

      assert Realm.astarte_keyspace_name() == expected_keyspace_name
    end
  end

  describe "list_realm_names/0" do
    test "returns the list of realm names", context do
      expected_realms = [context.realm_name]

      assert Realm.list_realm_names() == expected_realms
    end
  end
end
