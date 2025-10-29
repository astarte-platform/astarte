#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.FDOClient do
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.TO0Util

  require Logger

  @doc """
  TO0.Hello - Type 20 message to initiate TO0 protocol.
  Sends an empty array as per FDO specification section 5.3.1.
  Returns decoded TO0.HelloAck (message 21) with rendezvous nonce.
  """
  def to0_hello() do
    url = "#{fdo_rendezvous_url!()}/fdo/101/msg/20"

    headers = [
      {"Content-Type", "application/cbor"},
      {"Content-Length", "0"}
    ]

    request_body = CBOR.encode([])

    Logger.debug("Sending TO0.Hello to FDO rendezvous server...", url: url)

    case http_client().post(url, request_body, headers) do
      {:ok, %{status_code: 200, headers: headers, body: body}} ->
        Logger.debug("TO0.Hello completed successfully")
        Logger.debug(inspect(headers))

        case TO0Util.get_nonce_from_hello_ack(body) do
          {:ok, nonce} ->
            Logger.debug("Nonce retrieved from TO0.HelloAck", nonce: Base.encode16(nonce))
            to0_owner_sign(nonce, get_auth_bearer(headers))

          {:error, reason} ->
            Logger.error("Failed to get nonce from TO0.HelloAck", reason: reason)
        end

      {:ok, %{status_code: status_code, body: body}} ->
        Logger.error("TO0.Hello failed with:",
          status_code: status_code,
          response_body: body
        )

      {:error, reason} ->
        Logger.error("TO0.Hello HTTP request failed", reason: inspect(reason))
    end
  end

  defp get_auth_bearer(headers) do
    Enum.find_value(headers, fn
      {"authorization", value} ->
        Logger.debug("Authorization Bearer retrieved: #{inspect(value)}")
        value

      _ ->
        nil
    end)
  end

  @doc """
  TO0.OwnerSign - Type 22 message to register ownership.
  Sends ownership voucher and waits for response from rendezvous server.
  Returns decoded TO0.AcceptOwner (message 23) with negotiated wait time.
  """
  def to0_owner_sign(nonce, bearer) do
    Logger.debug("Sending TO0.OwnerSign...")

    with {:ok, owner_key} <- TO0Util.get_owner_private_key(),
         {:ok, ownership_voucher} <- TO0Util.get_ownership_voucher(),
         {:ok, addr_entries} <- TO0Util.get_astarte_rv_to2_addr_entries(),
         {:ok, request_body} <-
           TO0Util.build_owner_sign_message(ownership_voucher, owner_key, nonce, addr_entries) do
      url = "#{fdo_rendezvous_url!()}/fdo/101/msg/22"

      headers = [
        {"Content-Type", "application/cbor"},
        {"Content-Length", byte_size(request_body)},
        {"Authorization", bearer}
      ]

      Logger.debug("Sending TO0.OwnerSign", payload_size: byte_size(request_body))

      case http_client().post(url, request_body, headers) do
        {:ok, %{status_code: 200, body: _body}} ->
          Logger.debug("TO0.OwnerSign completed successfully!")

        {:ok, %{status_code: status_code, body: body}} ->
          Logger.error(
            "TO0.OwnerSign failed with status #{status_code}, response: #{inspect(body)}"
          )

        {:error, reason} ->
          Logger.error("TO0.OwnerSign request failed", reason: reason)
      end
    else
      {:error, reason} ->
        Logger.error("Failed to prepare TO0.OwnerSign message", reason: reason)
    end
  end

  defp fdo_rendezvous_url! do
    Config.fdo_rendezvous_url!()
  end

  defp http_client do
    Application.get_env(:astarte_pairing, :fdo_http_client, HTTPoison)
  end
end
