#
# This file is part of Astarte.
#
# Copyright 2017-2026 SECO Mind Srl
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

defmodule Astarte.PairingWeb.GraphQL.Auth do
  @moduledoc """
  Authorization helper for GraphQL resolvers.

  Replicates the authorization logic from `GuardianAuthorizePath` so that
  GraphQL mutations can verify that the JWT `a_pa` claims cover the
  requested HTTP method and resource path.
  """

  require Logger

  @doc """
  Verifies that the user's authorizations (from JWT `a_pa` claims) allow
  the given method on the given auth_path.

  Returns `:ok` if authorized, or `{:error, message}` if not.

  ## Examples

      iex> authorize("POST", "agent/devices", ["POST::agent/.*"])
      :ok

      iex> authorize("DELETE", "agent/devices/device123", ["GET::agent/.*"])
      {:error, "Unauthorized: ..."}
  """
  @spec authorize(String.t(), String.t(), list(String.t()) | nil) ::
          :ok | {:error, String.t()}
  def authorize(_method, _auth_path, nil) do
    {:error, "Unauthorized: No authorizations found in token"}
  end

  def authorize(_method, _auth_path, []) do
    {:error, "Unauthorized: No authorizations found in token"}
  end

  def authorize(method, auth_path, authorizations) when is_list(authorizations) do
    authorized =
      Enum.any?(authorizations, fn auth_string ->
        case parse_auth_string(auth_string) do
          {:ok, {method_regex, path_regex}} ->
            _ =
              Logger.debug(
                "GraphQL Auth: checking #{method} against #{inspect(method_regex)} and " <>
                  "#{auth_path} against #{inspect(path_regex)}."
              )

            Regex.match?(method_regex, method) and Regex.match?(path_regex, auth_path)

          _ ->
            false
        end
      end)

    if authorized do
      :ok
    else
      Logger.info(
          "GraphQL Auth: Unauthorized request: #{method} on #{auth_path}. " <>
            "Failed with authorizations #{inspect(authorizations)}.",
          tag: "unauthorized_graphql_request"
        )

      {:error, "Unauthorized: your token does not grant #{method} access to #{auth_path}"}
    end
  end

  @doc """
  Convenience function to check authorization from the Absinthe context.
  Extracts `current_user` and `realm_name`, and verifies the authorization.

  Returns `:ok` or `{:error, message}`.
  """
  @spec authorize_from_context(map(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def authorize_from_context(context, method, auth_path) do
    with {:realm, realm} when not is_nil(realm) <- {:realm, Map.get(context, :realm_name)},
         {:user, user} when not is_nil(user) <- {:user, Map.get(context, :current_user)} do
      authorize(method, auth_path, user.authorizations)
    else
      {:realm, nil} ->
        {:error, "Unauthorized: Missing realm. Provide the 'astarte-realm' header."}

      {:user, nil} ->
        {:error, "Unauthorized: Missing or invalid Agent JWT token."}
    end
  end

  # Parses an authorization string like "POST::agent/.*" into
  # {method_regex, path_regex}
  defp parse_auth_string(authorization_string) do
    with [method_auth, _opts, path_auth] <- String.split(authorization_string, ":", parts: 3),
         {:ok, method_regex} <- Regex.compile("^#{method_auth}$"),
         {:ok, path_regex} <- Regex.compile("^#{path_auth}$") do
      {:ok, {method_regex, path_regex}}
    else
      _ -> {:error, :invalid_authorization_string}
    end
  end
end
