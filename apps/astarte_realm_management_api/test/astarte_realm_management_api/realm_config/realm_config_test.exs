#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.RealmManagement.API.RealmConfig.RealmConfigTest do
  use Astarte.Cases.Data, async: true, jwt_public_key: "fake_pem"
  use ExUnitProperties

  alias Astarte.DataAccess.KvStore
  alias Astarte.Helpers
  alias Astarte.RealmManagement.API.RealmConfig.AuthConfig
  alias Astarte.RealmManagement.API.RealmConfig

  setup %{realm_name: realm_name, jwt_public_key: key, astarte_instance_id: astarte_instance_id} do
    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      insert_public_key!(realm_name, key)
    end)
  end

  test "get_auth_config/1 retrieves realm jwt", context do
    %{realm_name: realm_name, jwt_public_key: key} = context

    assert {:ok, %AuthConfig{jwt_public_key_pem: ^key}} = RealmConfig.get_auth_config(realm_name)
  end

  test "update_auth_config/2 sets the jwt public key pem", context do
    %{realm_name: realm_name} = context

    key = Helpers.Database.get_public_key()
    new_config = %{jwt_public_key_pem: key}

    assert :ok = RealmConfig.update_auth_config(realm_name, new_config)
    assert {:ok, %AuthConfig{jwt_public_key_pem: ^key}} = RealmConfig.get_auth_config(realm_name)
  end

  test "datastream_maximum_storage_retention/1 defaults to 0", %{realm: realm} do
    Mimic.stub(KvStore, :fetch_value, fn "realm_config",
                                         "datastream_maximum_storage_retention",
                                         :integer,
                                         _opts ->
      {:error, :fetch_error}
    end)

    assert {:ok, 0} = RealmConfig.get_datastream_maximum_storage_retention(realm)
  end

  property "retrieves datasteam_maximum_storage_retention correctly", %{realm: realm} do
    check all(retention <- integer(1..256)) do
      Helpers.Database.set_datastream_maximum_storage_retention(realm, retention)
      assert {:ok, ^retention} = RealmConfig.get_datastream_maximum_storage_retention(realm)
    end
  end
end
