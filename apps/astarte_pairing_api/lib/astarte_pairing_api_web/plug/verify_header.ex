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
#

defmodule Astarte.Pairing.APIWeb.Plug.VerifyHeader do
  @moduledoc """
  This is a wrapper around `Guardian.Plug.VerifyHeader` that allows to recover
  the JWT public key dynamically using informations contained in the connection
  """

  alias Astarte.Pairing.API.Auth
  alias Guardian.Plug.VerifyHeader, as: GuardianVerifyHeader
  alias JOSE.JWK

  def init(opts) do
    GuardianVerifyHeader.init(opts)
  end

  def call(conn, opts) do
    secrets = get_secrets(conn)

	# TODO: support multiple secrets
	secret = List.first(secrets)

    merged_opts =
      opts
      |> Keyword.merge(secret: secret)

    GuardianVerifyHeader.call(conn, merged_opts)
  end

  defp get_secrets(conn) do
    with %{"realm_name" => realm} <- conn.path_params,
         {:ok, [_pem | _] = public_key_pems} <- Auth.get_public_keys(realm) do
	  for public_key_pem <- public_key_pems do
        JWK.from_pem(public_key_pem)
	  end
    else
      _ ->
        []
    end
  end
end
