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
  end
end
