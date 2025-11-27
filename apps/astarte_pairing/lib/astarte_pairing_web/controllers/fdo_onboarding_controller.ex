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

defmodule Astarte.PairingWeb.FDOOnboardingController do
  use Astarte.PairingWeb, :controller

  alias Astarte.Pairing.FDO.OwnerOnboarding

  require Logger

  action_fallback Astarte.PairingWeb.FallbackController

  def hello_device(conn, _params) do
    realm_name = Map.fetch!(conn.params, "realm_name")
    cbor_hello_device = conn.assigns.cbor_body

    with {:ok, session_key, response_msg} <-
           OwnerOnboarding.hello_device(realm_name, cbor_hello_device) do
      conn
      |> put_resp_header("authorization", session_key)
      |> render("default.cbor", %{cbor_response: response_msg})
    end
  end

  def ov_next_entry(conn, _params) do
    realm_name = Map.fetch!(conn.params, "realm_name")
    cbor_body = conn.assigns.cbor_body

    device_id = conn.assigns.to2_session.device_id

    with {:ok, response} <-
           OwnerOnboarding.ov_next_entry(cbor_body, realm_name, device_id) do
      conn
      |> render("default.cbor", %{cbor_response: response})
    end
  end

  def prove_device(conn, _params) do
    realm_name = Map.fetch!(conn.params, "realm_name")
    cbor_body = conn.assigns.cbor_body

    with {:ok, response} <-
           OwnerOnboarding.prove_device(
             realm_name,
             cbor_body,
             conn.assigns.to2_session
           ) do
      conn
      |> render("default.cbor", %{cbor_response: response})
    end
  end

  def done(conn, _params) do
    # TODO extract message from secure tunnel
    cbor_body = conn.assigns.cbor_body
    to2_session = conn.assigns.to2_session

    case OwnerOnboarding.done(to2_session, cbor_body) do
      {:ok, response_msg} ->
        conn
        |> put_resp_content_type("application/cbor")
        # TODO put msg in secure tunnel
        |> send_resp(200, response_msg)
    end
  end
end
