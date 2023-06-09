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

defmodule Astarte.Housekeeping.APIWeb.Plug.GuardianAuthorizePath do
  use Plug.Builder

  import Plug.Conn

  require Logger

  alias Astarte.Housekeeping.API.Auth.User
  alias Astarte.Housekeeping.APIWeb.AuthGuardian
  alias Astarte.Housekeeping.APIWeb.FallbackController

  plug Guardian.Plug.Pipeline,
    otp_app: :astarte_housekeeping_api,
    module: Astarte.Housekeeping.APIWeb.AuthGuardian,
    error_handler: FallbackController

  plug Astarte.Housekeeping.APIWeb.Plug.VerifyHeader
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
  plug :authorize

  defp authorize(conn, opts) do
    with %User{authorizations: authorizations} <- AuthGuardian.Plug.current_resource(conn),
         {:ok, auth_path} <- build_auth_path(conn),
         :ok <- is_path_authorized?(conn.method, auth_path, authorizations) do
      conn
    else
      {:error, :invalid_auth_path} ->
        Logger.warn(
          "Can't build auth_path with path_params: #{inspect(conn.path_params)} path_info: #{inspect(conn.path_info)} query_params: #{inspect(conn.query_params)}"
        )

        conn
        |> FallbackController.auth_error({:unauthorized, :invalid_auth_path}, opts)
        |> halt()

      {:error, {:unauthorized, method, auth_path, authorizations}} ->
        Logger.info(
          "Unauthorized request: #{method} #{auth_path} failed with authorizations #{inspect(authorizations)}"
        )

        conn
        |> FallbackController.auth_error({:unauthorized, :authorization_path_not_matched}, opts)
        |> halt()
    end
  end

  defp build_auth_path(conn) do
    with [_api_version | rest] <- conn.path_info do
      {:ok, Enum.join(rest, "/")}
    else
      _ ->
        {:error, :invalid_auth_path}
    end
  end

  defp is_path_authorized?(method, auth_path, authorizations) when is_list(authorizations) do
    authorized =
      Enum.any?(authorizations, fn auth_string ->
        case get_auth_regex(auth_string) do
          {:ok, {method_regex, path_regex}} ->
            Regex.match?(method_regex, method) and Regex.match?(path_regex, auth_path)

          _ ->
            false
        end
      end)

    if authorized do
      :ok
    else
      {:error, {:unauthorized, method, auth_path, authorizations}}
    end
  end

  defp is_path_authorized?(method, auth_path, authorizations),
    do: {:error, {:unauthorized, method, auth_path, authorizations}}

  defp get_auth_regex(authorization_string) do
    with [method_auth, _opts, path_auth] <- String.split(authorization_string, ":", parts: 3),
         {:ok, method_regex} <- build_regex(method_auth),
         {:ok, path_regex} <- build_regex(path_auth) do
      {:ok, {method_regex, path_regex}}
    else
      [] ->
        {:error, :invalid_authorization_string}

      _ ->
        {:error, :invalid_regex}
    end
  end

  defp build_regex(auth_string) do
    Regex.compile("^#{auth_string}$")
  end
end
