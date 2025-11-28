#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.FDO.Rendezvous do
  alias Astarte.Pairing.FDO.Cbor.Core, as: CBORCore
  alias Astarte.Pairing.FDO.Rendezvous.Client
  alias Astarte.Pairing.FDO.Rendezvous.Core

  require Logger

  def send_hello() do
    headers = [
      {"Content-Type", "application/cbor"},
      {"Content-Length", "0"}
    ]

    request_body = CBORCore.empty_payload()

    with {:ok, response} <- send_hello_message(request_body, headers),
         {:ok, nonce} <- get_nonce(response) do
      {:ok, %{nonce: nonce, headers: response.headers}}
    end
  end

  def register_ownership(request_body, headers) do
    headers = [
      {"Content-Type", "application/cbor"},
      {"Content-Length", byte_size(request_body)},
      {"Authorization", get_auth_bearer(headers)}
    ]

    with {:ok, body} <- send_owner_sign_message(request_body, headers) do
      verify_accept_owner_response(body)
    end
  end

  defp send_owner_sign_message(request_body, headers) do
    case Client.post("/fdo/101/msg/22", request_body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, response} ->
        "error during owner sign message: unexpected response #{inspect(response)}"
        |> Logger.error()

        :error

      {:error, reason} ->
        "error during owner sign message: http error #{inspect(reason)}"
        |> Logger.error()

        :error
    end
  end

  defp verify_accept_owner_response(accept_owner_body) do
    with {:ok, message, _} <- CBOR.decode(accept_owner_body),
         [wait_seconds] when is_integer(wait_seconds) <- message do
      {:ok, wait_seconds}
    else
      _ ->
        "error during owner sign message: invalid response body #{inspect(accept_owner_body)}"
        |> Logger.error()

        :error
    end
  end

  defp send_hello_message(body, headers) do
    case Client.post("/fdo/101/msg/20", body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        {:ok, response}

      {:ok, response} ->
        "error during hello message: unexpected response #{inspect(response)}"
        |> Logger.error()

        :error

      {:error, reason} ->
        "error during hello message: http error #{inspect(reason)}"
        |> Logger.error()

        :error
    end
  end

  defp get_nonce(response) do
    case Core.get_body_nonce(response.body) do
      {:ok, nonce} ->
        {:ok, nonce}

      {:error, reason} ->
        "error during error message: invalid nonce #{inspect(reason)}"
        |> Logger.error()

        :error
    end
  end

  defp get_auth_bearer(headers) do
    Enum.find_value(headers, fn
      {"authorization", value} ->
        value

      _ ->
        false
    end)
  end
end
