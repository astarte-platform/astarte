#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.Pairing.APIWeb.JWTTestHelper do
  alias Astarte.Pairing.API.Auth.User
  alias Astarte.Pairing.APIWeb.AuthGuardian

  def agent_public_key_pems do
    Application.get_env(:astarte_pairing_api, :agent_public_key_pems)
  end

  def gen_jwt_token(authorization_paths) do
    jwk =
      Application.get_env(:astarte_pairing_api, :test_priv_key)
      |> JOSE.JWK.from_map()

    {:ok, jwt, _claims} =
      %User{id: "testuser"}
      |> AuthGuardian.encode_and_sign(
        %{a_pa: authorization_paths},
        secret: jwk,
        allowed_algos: ["RS256"]
      )

    jwt
  end

  def gen_jwt_token_with_wrong_signature(authorization_paths) do
    valid_token = gen_jwt_token(authorization_paths)

    [header, payload, _signature] = String.split(valid_token, ".")

    fake_signature = "fake_signature"

    "#{header}.#{payload}.#{fake_signature}"
  end

  def gen_jwt_all_access_token do
    gen_jwt_token([".*::.*"])
  end
end
