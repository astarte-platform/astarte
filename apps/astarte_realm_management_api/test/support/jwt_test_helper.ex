# Copyright 2017-2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.RealmManagement.API.JWTTestHelper do
  alias Astarte.RealmManagement.API.Auth.User
  alias Astarte.RealmManagement.APIWeb.AuthGuardian

  def public_key_pem do
    Application.get_env(:astarte_realm_management_api, :test_pub_key_pem)
  end

  def gen_jwt_token(authorization_paths) do
    jwk =
      Application.get_env(:astarte_realm_management_api, :test_priv_key)
      |> JOSE.JWK.from_map()

    {:ok, jwt, _claims} =
      %User{id: "testuser"}
      |> AuthGuardian.encode_and_sign(
        %{a_rma: authorization_paths},
        secret: jwk,
        allowed_algos: ["RS256"]
      )

    jwt
  end

  def gen_jwt_all_access_token do
    gen_jwt_token([".*::.*"])
  end
end
