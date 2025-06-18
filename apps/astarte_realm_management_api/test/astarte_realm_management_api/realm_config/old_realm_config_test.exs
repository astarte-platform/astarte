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

defmodule Astarte.RealmManagement.API.RealmConfigTest do
  use Astarte.RealmManagement.API.DataCase, async: true

  alias Astarte.RealmManagement.API.RealmConfig

  describe "auth config" do
    alias Astarte.RealmManagement.API.Helpers.JWTTestHelper
    alias Astarte.RealmManagement.API.Helpers.RPCMock.DB

    setup %{realm: realm} do
      DB.put_jwt_public_key_pem(realm, JWTTestHelper.public_key_pem())
    end

    test "get_device_registration_limit/1 returns the limit for an existing realm", %{
      realm: realm
    } do
      limit = 10
      DB.put_device_registration_limit(realm, limit)

      assert {:ok, ^limit} = RealmConfig.get_device_registration_limit(realm)
    end
  end
end
