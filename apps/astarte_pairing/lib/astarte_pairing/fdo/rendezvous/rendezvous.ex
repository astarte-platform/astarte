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
  alias AstartePairing.Fdo.Cbor.Core, as: CBORCore

  alias Astarte.Pairing.FDO.Rendezvous.Client
  require Logger

  def send_hello() do
    headers = [
      {"Content-Type", "application/cbor"},
      {"Content-Length", "0"}
    ]

    request_body = CBORCore.empty_payload()

    case Client.post("/fdo/101/msg/20", request_body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

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

  def register_ownership(request_body, headers) do
    headers = [
      {"Content-Type", "application/cbor"},
      {"Content-Length", byte_size(request_body)},
      {"Authorization", get_auth_bearer(headers)}
    ]

    case Client.post("/fdo/101/msg/22", request_body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, response} ->
        "error during owner sign message: unexpected response #{inspect(response)}"
        |> Logger.error()

        :error

      {:error, reason} ->
        "error during hello message: http error #{inspect(reason)}"
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
