# Copyright 2018-2019 SECO Mind Srl
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

defmodule Astarte.Pairing.APIWeb.Plug.VerifyHeader do
  @moduledoc """
  This is a wrapper around `Guardian.Plug.VerifyHeader` that allows to recover
  the JWT public key dynamically using informations contained in the connection
  """
  require Logger

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
      error ->
        _ =
          Logger.error("Couldn't get JWT public key PEM: #{inspect(error)}.",
            tag: "get_jwt_secret_error"
          )

        []
    end
  end
end
