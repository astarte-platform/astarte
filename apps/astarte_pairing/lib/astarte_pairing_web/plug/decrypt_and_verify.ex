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

defmodule Astarte.PairingWeb.Plug.DecryptAndVerify do
  use Plug.Builder

  import Plug.Conn

  alias Astarte.Pairing.FDO.OwnerOnboarding.Session

  def init(_opts) do
    nil
  end

  def call(conn, _opts) do
    session = conn.assigns.to2_session
    body = conn.assigns.cbor_body

    # TODO: send error message 101
    case Session.decrypt_and_verify(session, body) do
      {:ok, body} -> assign(conn, :cbor_body, body)
      :error -> conn |> send_resp(500, "") |> halt()
    end
  end
end
