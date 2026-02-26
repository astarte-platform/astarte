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

defmodule Astarte.PairingWeb.Plug.FDOSession do
  use Plug.Builder

  import Plug.Conn

  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.PairingWeb.FDOFallbackController

  def init(_opts) do
    nil
  end

  def call(conn, _opts) do
    realm_name = Map.fetch!(conn.path_params, "realm_name")

    with [token] <- get_req_header(conn, "authorization"),
         {:ok, guid, token_nonce} <-
           Astarte.Pairing.FDO.OwnerOnboarding.SessionToken.verify(token),
         {:ok, session} <- Session.fetch(realm_name, guid),
         :ok <- verify_nonce(session.nonce, token_nonce) do
      conn
      |> put_resp_header("authorization", token)
      |> assign(:to2_session, session)
    else
      _ -> FDOFallbackController.invalid_token(conn)
    end
  end

  defp verify_nonce(session_nonce, token_nonce) do
    if session_nonce == token_nonce, do: :ok, else: {:error, :invalid_nonce}
  end
end
