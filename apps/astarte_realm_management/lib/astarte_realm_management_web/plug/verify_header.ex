#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.RealmManagementWeb.Plug.VerifyHeader do
  @moduledoc """
  This is a wrapper around `Guardian.Plug.VerifyHeader` that allows to recover
  the JWT public key dynamically using information contained in the connection
  """

  alias Astarte.RealmManagement.Auth
  alias Guardian.Plug.VerifyHeader, as: GuardianVerifyHeader
  alias JOSE.JWK

  def init(opts) do
    GuardianVerifyHeader.init(opts)
  end

  def call(conn, opts) do
    secret =
      case fetch_secret(conn) do
        {:ok, secret} -> secret
        {:error, _reason} -> nil
      end

    opts_list = if is_map(opts), do: Map.to_list(opts), else: opts

    merged_opts =
      opts_list
      |> Keyword.merge(secret: secret)

    GuardianVerifyHeader.call(conn, merged_opts)
  end

  defp fetch_secret(conn) do
    with realm when is_binary(realm) <- realm_name(conn),
         {:ok, public_key_pem} <- Auth.fetch_public_key(realm) do
      {:ok, JWK.from_pem(public_key_pem)}
    else
      _ -> {:error, :not_found}
    end
  end

  defp realm_name(conn) do
    conn.assigns[:realm_name] || Map.get(conn.path_params, "realm_name") ||
      conn |> Plug.Conn.get_req_header("astarte-realm") |> List.first()
  end
end
