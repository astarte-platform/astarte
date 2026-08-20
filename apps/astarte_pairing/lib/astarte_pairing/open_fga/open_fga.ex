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

defmodule Astarte.Pairing.OpenFGA do
  @moduledoc """
  Exposes authorization checks against the OpenFGA server configured via
  `Astarte.Pairing.Config`.
  """

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.OpenFGA.Client

  require Logger

  @doc """
  Checks whether `user` has `relation` on `object` in the configured
  OpenFGA store.

  Returns `:ok` if the check is allowed, `{:error, :forbidden}` if OpenFGA
  explicitly denied it, or `{:error, reason}` if the check itself couldn't
  be completed: the request failed, OpenFGA returned an unexpected HTTP
  status, or its response body wasn't the shape we expect.
  """
  @spec check(String.t(), String.t(), String.t()) ::
          :ok | {:error, :forbidden} | {:error, term()}
  def check(user, relation, object) do
    store_id = Config.openfga_store_id!()
    url = "/stores/#{store_id}/check"

    body =
      Jason.encode!(%{
        tuple_key: %{user: user, relation: relation, object: object}
      })

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
