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

defmodule Astarte.PairingWeb.FDOFallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Astarte.PairingWeb, :controller

  require Logger

  @invalid_jwt_token 001
  @resource_not_found 006
  @message_body_error 100
  @invalid_message_error 101
  @cred_reuse_error 102
  @internal_server_error 500

  def call(conn, {:error, :resource_not_found}) do
    fdo_error(conn, @resource_not_found)
  end

  def call(conn, {:error, :message_body_error}) do
    fdo_error(conn, @message_body_error)
  end

  def call(conn, {:error, :invalid_message}) do
    fdo_error(conn, @invalid_message_error)
  end

  def call(conn, {:error, :cred_reuse_rejected}) do
    fdo_error(conn, @cred_reuse_error)
  end

  def call(conn, error) do
    Logger.error("FDO internal server error: #{inspect(error)}")

    fdo_error(conn, @internal_server_error)
  end

  def invalid_message(conn) do
    fdo_error(conn, @invalid_message_error)
  end

  def message_body_error(conn) do
    fdo_error(conn, @message_body_error)
  end

  def invalid_token(conn) do
    fdo_error(conn, @invalid_jwt_token)
  end

  defp fdo_error(conn, error_code) do
    correlation_id = get_correlation_id(conn)

    conn
    |> assign(:correlation_id, correlation_id)
    |> put_status(500)
    |> put_resp_header("message-type", "255")
    |> render("error.cbor", %{error_code: error_code})
  end

  defp get_correlation_id(conn) do
    with [request_id] <- get_resp_header(conn, "x-request-id"),
         {:ok, bin} <- Base.decode64(request_id) do
      binary_slice(bin, 0, div(128, 8))
      |> :binary.decode_unsigned()
    else
      _ -> 0
    end
  end
end
