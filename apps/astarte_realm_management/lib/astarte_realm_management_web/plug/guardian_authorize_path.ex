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

defmodule Astarte.RealmManagementWeb.Plug.GuardianAuthorizePath do
  @moduledoc """
  Enforces path-based authorization using Guardian.
  """
  use Plug.Builder

  import Plug.Conn

  require Logger

  alias Astarte.RealmManagement.Auth.User
  alias Astarte.RealmManagementWeb.AuthGuardian
  alias Astarte.RealmManagementWeb.FallbackController

  plug Guardian.Plug.Pipeline,
    otp_app: :astarte_realm_management,
    module: Astarte.RealmManagementWeb.AuthGuardian,
    error_handler: FallbackController

  plug Astarte.RealmManagementWeb.Plug.VerifyHeader
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
  plug :authorize

  defp authorize(conn, opts) do
    %User{authorizations: authorizations} = AuthGuardian.Plug.current_resource(conn)

    case build_auth_path(conn) do
      {:ok, auth_path} ->
        authorize_path(conn, opts, auth_path, authorizations)

      {:error, :invalid_auth_path} ->
        reject_invalid_auth_path(conn, opts)
    end
  end

  defp authorize_path(conn, opts, auth_path, authorizations) do
    case path_authorized?(conn.method, auth_path, authorizations) do
      :ok ->
        conn

      {:error, {:unauthorized, method, auth_path, authorizations}} ->
        _ =
          Logger.info(
            "Unauthorized request on #{auth_path} failed with authorizations: " <>
              "#{inspect(authorizations)}.",
            method: method,
            tag: "unauthorized_request"
          )

        conn
        |> FallbackController.auth_error({:unauthorized, :authorization_path_not_matched}, opts)
        |> halt()
    end
  end

  defp reject_invalid_auth_path(conn, opts) do
    _ =
      Logger.warning(
        "Can't build auth_path with path_params: #{inspect(conn.path_params)} " <>
          "path_info: #{inspect(conn.path_info)} query_params: #{inspect(conn.query_params)}.",
        tag: "invalid_request"
      )

    conn
    |> FallbackController.auth_error({:unauthorized, :invalid_auth_path}, opts)
    |> halt()
  end

  defp build_auth_path(conn) do
    with %{"realm_name" => realm} <- conn.path_params,
         [^realm | rest] <- Enum.drop_while(conn.path_info, fn token -> token != realm end) do
      {:ok, Enum.join(rest, "/")}
    else
      _ ->
        {:error, :invalid_auth_path}
    end
  end

  defp path_authorized?(method, auth_path, authorizations) when is_list(authorizations) do
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

  defp path_authorized?(method, auth_path, authorizations),
    do: {:error, {:unauthorized, method, auth_path, authorizations}}

  defp get_auth_regex(authorization_string) do
    case String.split(authorization_string, ":", parts: 3) do
      [method_auth, _opts, path_auth] ->
        build_regex_pair(method_auth, path_auth)

      _ ->
        {:error, :invalid_authorization_string}
    end
  end

  defp build_regex_pair(method_auth, path_auth) do
    with {:ok, method_regex} <- build_regex(method_auth),
         {:ok, path_regex} <- build_regex(path_auth) do
      {:ok, {method_regex, path_regex}}
    else
      _ -> {:error, :invalid_regex}
    end
  end

  defp build_regex(auth_string) do
    Regex.compile("^#{auth_string}$")
  end
end
