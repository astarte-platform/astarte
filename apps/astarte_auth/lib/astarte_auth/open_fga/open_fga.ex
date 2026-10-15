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

defmodule Astarte.Auth.OpenFGA do
  @moduledoc """
  Exposes authorization checks against the OpenFGA server configured via
  `Astarte.Auth.Config`.
  """

  alias Astarte.Auth.Config
  alias Astarte.Auth.OpenFGA.Client

  require Logger

  @doc """
  Checks whether `user` has `relation` on `object` in the configured
  OpenFGA store.

  Returns `:ok` if the check is allowed, `{:error, :forbidden}` if OpenFGA
  explicitly denied it, or `{:error, reason}` if the check itself couldn't
  be completed: no store is configured, the request failed, OpenFGA returned
  an unexpected HTTP status, or its response body wasn't the shape we expect.
  """
  @spec check(String.t(), String.t(), String.t(), list(map())) ::
          :ok | {:error, :forbidden} | {:error, term()}
  def check(user, relation, object, contextual_tuples \\ []) do
    case Config.openfga_store_id!() do
      store_id when store_id in [nil, ""] ->
        Logger.error("OpenFGA store id is not configured")
        {:error, :store_not_configured}

      store_id ->
        do_check(store_id, user, relation, object, contextual_tuples)
    end
  end

  defp do_check(store_id, user, relation, object, contextual_tuples) do
    url = "/stores/#{store_id}/check"

    body_map = %{
      tuple_key: %{user: user, relation: relation, object: object}
    }

    body_map =
      if contextual_tuples != [] do
        Map.put(body_map, :contextual_tuples, %{tuple_keys: contextual_tuples})
      else
        body_map
      end

    body = Jason.encode!(body_map)

    headers = [{"Content-Type", "application/json"}]

    case Client.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        handle_response(resp_body)

      {:ok, %HTTPoison.Response{status_code: status, body: resp_body}} ->
        Logger.warning("OpenFGA check returned status #{status}: #{inspect(resp_body)}")
        {:error, {:unexpected_status, status}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenFGA request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_response(resp_body) do
    case Jason.decode(resp_body) do
      {:ok, %{"allowed" => true}} ->
        :ok

      {:ok, %{"allowed" => false}} ->
        {:error, :forbidden}

      {:ok, unexpected} ->
        Logger.warning("OpenFGA check response missing \"allowed\": #{inspect(unexpected)}")
        {:error, :unexpected_response}

      {:error, decode_error} ->
        Logger.warning("OpenFGA check returned an unparsable body: #{inspect(decode_error)}")
        {:error, :unexpected_response}
    end
  end
end
