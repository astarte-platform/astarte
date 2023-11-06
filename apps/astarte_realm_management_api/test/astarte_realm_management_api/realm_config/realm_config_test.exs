#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.RealmManagement.API.RealmConfigTest do
  use Astarte.RealmManagement.API.DataCase

  alias Astarte.RealmManagement.API.RealmConfig
  alias Astarte.RealmManagement.API.RealmConfig.AuthConfig

  describe "auth config" do
    alias Astarte.RealmManagement.API.JWTTestHelper
    alias Astarte.RealmManagement.Mock.DB

    @pubkey """
    -----BEGIN PUBLIC KEY-----
    MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE6ssZpULEsn+wSQdc+DI2+4aj98a1hDKM
    +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
    -----END PUBLIC KEY-----
    """

    @malformed_pubkey """
    -----BEGIN PUBLIC KEY-----
    MFYwEAYHKoZIzj0CAQYAoDQgAE6ssZpw4aj98a1hDKM
    +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
    -----END PUBLIC KEY-----
    """

    @realm "mock_realm"
    @update_attrs %{jwt_public_key_pem: @pubkey}
    @invalid_pubkey_attrs %{jwt_public_key_pem: "invalid"}
    @malformed_pubkey_attrs %{jwt_public_key_pem: @malformed_pubkey}
    @empty_pubkey_attrs %{jwt_public_key_pem: nil}

    setup do
      DB.put_jwt_public_key_pem(@realm, JWTTestHelper.public_key_pem())
    end

    test "get_auth_config/1 returns the auth config for the given realm" do
      assert RealmConfig.get_auth_config(@realm) ==
               {:ok, %AuthConfig{jwt_public_key_pem: JWTTestHelper.public_key_pem()}}
    end

    test "update_auth_config/2 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               RealmConfig.update_auth_config(@realm, @empty_pubkey_attrs)

      assert {:error, %Ecto.Changeset{}} =
               RealmConfig.update_auth_config(@realm, @invalid_pubkey_attrs)

      assert {:error, %Ecto.Changeset{}} =
               RealmConfig.update_auth_config(@realm, @malformed_pubkey_attrs)
    end

    test "update_auth_config/2 with valid data returns :ok and changes the data" do
      assert :ok = RealmConfig.update_auth_config(@realm, @update_attrs)

      assert RealmConfig.get_auth_config(@realm) ==
               {:ok, %AuthConfig{jwt_public_key_pem: @pubkey}}
    end

    test "get_device_registration_limit/1 returns the limit for an existing realm" do
      limit = 10
      DB.put_device_registration_limit(@realm, limit)

      assert {:ok, ^limit} = RealmConfig.get_device_registration_limit(@realm)
    end
  end
end
