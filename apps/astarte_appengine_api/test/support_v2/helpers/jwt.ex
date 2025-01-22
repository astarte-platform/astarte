#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.Test.Helpers.JWT do
  alias Astarte.AppEngine.API.Auth.User
  alias Astarte.AppEngine.APIWeb.AuthGuardian

  def public_key_pem do
    Application.get_env(:astarte_appengine_api, :test_pub_key_pem)
  end

  def gen_jwt_token(authorization_paths) do
    jwk =
      Application.get_env(:astarte_appengine_api, :test_priv_key)
      |> JOSE.JWK.from_map()

    {:ok, jwt, claims} =
      %User{id: "testuser"}
      |> AuthGuardian.encode_and_sign(
        %{a_aea: authorization_paths},
        secret: jwk,
        allowed_algos: ["RS256"]
      )

    {jwt, claims}
  end

  def gen_jwt_all_access_token do
    gen_jwt_token([".*::.*"])
  end

  def gen_channels_jwt_token(authorization_paths) do
    jwk =
      Application.get_env(:astarte_appengine_api, :test_priv_key)
      |> JOSE.JWK.from_map()

    {:ok, jwt, _claims} =
      %User{id: "testuser"}
      |> AuthGuardian.encode_and_sign(
        %{a_ch: authorization_paths},
        secret: jwk,
        allowed_algos: ["RS256"]
      )

    jwt
  end

  def gen_channels_jwt_all_access_token do
    gen_channels_jwt_token(["JOIN::.*", "WATCH::.*"])
  end
end
