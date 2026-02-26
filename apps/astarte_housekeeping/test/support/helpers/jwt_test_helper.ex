#
# This file is part of Astarte.
#
# Copyright 2018-2025 SECO Mind Srl
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

defmodule Astarte.Helpers.JWTTestHelper do
  @moduledoc false
  alias Astarte.Housekeeping.Auth.User
  alias Astarte.HousekeepingWeb.AuthGuardian

  def gen_jwt_token(authorization_paths) do
    jwk = JOSE.JWK.from_map(Application.get_env(:astarte_housekeeping, :test_priv_key))

    {:ok, jwt, _claims} =
      AuthGuardian.encode_and_sign(
        %User{id: "testuser"},
        %{a_ha: authorization_paths},
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
