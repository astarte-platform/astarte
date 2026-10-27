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

defmodule Astarte.PairingWeb.Plug.VerifyHeader do
  @moduledoc """
  This is a wrapper around `Guardian.Plug.VerifyHeader` that allows to recover
  the JWT public key dynamically using information contained in the connection
  """
  alias Astarte.Core.Realm
  alias Astarte.Pairing.Auth
  alias Guardian.Plug.VerifyHeader, as: GuardianVerifyHeader
  alias JOSE.JWK

  require Logger

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
    with {:ok, realm} <- fetch_realm_name(conn),
         {:ok, [_pem | _] = public_key_pems} <- Auth.get_public_keys(realm) do
      for public_key_pem <- public_key_pems do
        JWK.from_pem(public_key_pem)
      end
    else
      error ->
        _ =
          Logger.error("Couldn't get JWT public key PEM: #{inspect(error)}.",
            tag: "get_jwt_secret_error"
          )

        []
    end
  end

  # GraphQL requests have the realm in the astarte-realm header
  defp fetch_realm_name(conn) do
    with :error <- Map.fetch(conn.path_params, "realm_name") do
      case Plug.Conn.get_req_header(conn, "astarte-realm") do
        [realm | _] -> if Realm.valid_name?(realm), do: {:ok, realm}, else: :error
        [] -> :error
      end
    end
  end
end
