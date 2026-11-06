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

defmodule Astarte.AppEngine.APIWeb.AuthGuardianTest do
  use ExUnit.Case, async: true

  alias Astarte.AppEngine.API.Auth.User
  alias Astarte.AppEngine.APIWeb.AuthGuardian

  describe "resource_from_claims/1" do
    test "loads the subject, the authorizations and the roles" do
      claims = %{"sub" => "testuser", "a_aea" => [".*::.*"], "roles" => ["data_reader"]}

      assert {:ok, %User{id: "testuser", authorizations: [".*::.*"], roles: ["data_reader"]}} =
               AuthGuardian.resource_from_claims(claims)
    end

    test "defaults to no roles" do
      assert {:ok, %User{roles: []}} = AuthGuardian.resource_from_claims(%{"sub" => "testuser"})
    end
  end
end
