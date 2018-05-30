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
# Copyright (C) 2017-2018 Ispirata Srl
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

  def gen_jwt_all_access_token do
    gen_jwt_token([".*::.*"])
  end
end
