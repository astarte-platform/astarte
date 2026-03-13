#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Pairing.FDO.OpenBao do
  @moduledoc """
  Functionality to interface with OpenBao APIs.
  """

  alias Astarte.Pairing.FDO.OpenBao.{Client, Core}

  require Logger

  @allowed_fdo_key_types [:ec256, :ec384, :rsa2048, :rsa3072]

  @spec create_keypair(String.t(), atom(), list()) :: {:ok, map()} | {:error, atom()}
  def create_keypair(key_name, key_type, opts \\ []) do
    allow_key_export_and_backup = Keyword.get(opts, :allow_key_export_and_backup, false)
    auth_token = Keyword.get(opts, :auth_token, nil)

    case key_type in @allowed_fdo_key_types do
      true ->
        req_body =
          %{
            type: Core.key_type_to_string(key_type),
            exportable: allow_key_export_and_backup,
            allow_plaintext_backup: allow_key_export_and_backup
          }
          |> Jason.encode!()

        headers = build_custom_headers(auth_token)

        case Client.request(:post, "/v1/transit/keys/#{key_name}", req_body, headers) do
          {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
            pub_key_data = resp_body |> Jason.decode!() |> Map.get("data")
            {:ok, pub_key_data}

          error_resp ->
            handle_error_response(error_resp)
        end

      false ->
        {:error, :unsupported_key_type}
    end
  end

  @spec enable_key_deletion(String.t()) :: {:ok, map()} | {:error, atom()}
  def enable_key_deletion(key_name, opts \\ []) do
    auth_token = Keyword.get(opts, :auth_token, nil)

    req_body = %{deletion_allowed: true} |> Jason.encode!()

    headers = build_custom_headers(auth_token)

    case Client.request(:post, "/v1/transit/keys/#{key_name}/config", req_body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, %{}}

      error_resp ->
        handle_error_response(error_resp)
    end
  end

  @spec delete_key(String.t()) :: {:ok, map()} | {:error, atom()}
  def delete_key(key_name, opts \\ []) do
    auth_token = Keyword.get(opts, :auth_token, nil)

    headers = build_custom_headers(auth_token)

    case Client.request(:delete, "/v1/transit/keys/#{key_name}", "", headers) do
      {:ok, %HTTPoison.Response{status_code: 204}} ->
        {:ok, %{}}

      error_resp ->
        handle_error_response(error_resp)
    end
  end

  # custom headers to properly interact with OpenBao
  defp build_custom_headers(custom_token) do
    base_header = [{"Content-Type", "application/json"}]

    case custom_token do
      nil -> base_header
      token -> [{"X-Vault-Token", token} | base_header]
    end
  end

  defp handle_error_response(error_response) do
    case error_response do
      {:ok, %HTTPoison.Response{body: resp_body}} ->
        Logger.error("Received HTTP error response: #{inspect(resp_body)}")

      {:error, reason} ->
        Logger.error("Encountered HTTP failure: #{inspect(reason)}")
    end

    {:error, :http_error}
  end
end
