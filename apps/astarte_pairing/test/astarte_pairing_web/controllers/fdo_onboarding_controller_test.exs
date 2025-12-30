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

defmodule Astarte.PairingWeb.FDOOnboardingControllerTest do
  use Astarte.PairingWeb.CBORConnCase, async: true
  use Astarte.Cases.Data
  use Astarte.Cases.FDOSession
  use Mimic

  alias Astarte.Pairing.FDO.OwnerOnboarding
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.ServiceInfo

  setup :verify_on_exit!

  defp assert_cbor_error(conn) do
    assert get_resp_header(conn, "message-type") == ["255"]
    response = response(conn, 500)

    {:ok, [code, message_id, _, _, _], _} = CBOR.decode(response)
    {code, message_id}
  end

  defp cbor_response(conn) do
    resp = response(conn, 200)
    assert {:ok, decoded, ""} = CBOR.decode(resp)
    decoded
  end

  defp setup_authenticated(context, action, message_id) do
    %{conn: conn, realm_name: realm, session: %Session{key: session_key}} = context

    conn = put_req_header(conn, "authorization", session_key)

    %{
      conn: conn,
      create_path: fdo_onboarding_path(conn, action, realm),
      realm_name: realm,
      message_id: message_id
    }
  end

  describe "HelloDevice" do
    setup context do
      setup_authenticated(context, :hello_device, 60)
    end

    test "calls `OwnerOnboarding.hello_device/2`", %{
      conn: conn,
      create_path: path,
      message_id: id
    } do
      payload = CBOR.encode(%{hello: "device"})
      expected_response = %{"response" => true}

      expect(OwnerOnboarding, :hello_device, fn _, _ ->
        {:ok, "session_key", CBOR.encode(expected_response)}
      end)

      conn = post(conn, path, payload)

      assert get_resp_header(conn, "authorization") == ["session_key"]
      assert cbor_response(conn) == expected_response
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a hello device", %{
      conn: conn,
      create_path: path,
      message_id: id
    } do
      conn = post(conn, path, CBOR.encode(%{hello: "device"}))
      assert {100, id} == assert_cbor_error(conn)
    end
  end

  describe "OVNextEntry" do
    setup context do
      setup_authenticated(context, :ov_next_entry, 62)
    end

    test "calls `OwnerOnboarding.ov_next_entry/3`", %{
      conn: conn,
      create_path: path,
      message_id: id
    } do
      expected_response = %{"result" => true}

      expect(OwnerOnboarding, :ov_next_entry, fn _, _, _ ->
        {:ok, CBOR.encode(expected_response)}
      end)

      conn = post(conn, path, CBOR.encode(%{next: "entry"}))
      assert cbor_response(conn) == expected_response
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a GetOVNextEntry",
         %{
           conn: conn,
           create_path: path,
           message_id: id
         } do
      conn = post(conn, path, CBOR.encode(%{next: "entry"}))
      assert {100, id} == assert_cbor_error(conn)
    end
  end

  describe "ProveDevice" do
    setup context do
      setup_authenticated(context, :prove_device, 64)
    end

    test "calls `OwnerOnboarding.prove_device/3`", %{
      conn: conn,
      create_path: path,
      message_id: id,
      session: session
    } do
      expected_response = %{"result" => true}

      expect(OwnerOnboarding, :prove_device, fn _, _, _ ->
        {:ok, session, expected_response}
      end)

      request_body = Session.encrypt_and_sign(session, CBOR.encode(%{prove: "device"}))

      conn = post(conn, path, request_body)

      http_response = response(conn, 200)
      assert {:ok, decoded_response} = Session.decrypt_and_verify(session, http_response)
      assert decoded_response == expected_response
      assert conn.assigns.to2_session == session
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a ProveDevice", %{
      conn: conn,
      create_path: path,
      message_id: id
    } do
      conn = post(conn, path, CBOR.encode(%{prove: "device"}))
      assert {100, id} == assert_cbor_error(conn)
    end
  end

  describe "DeviceServiceInfoReady" do
    setup context do
      setup_authenticated(context, :service_info_start, 66)
    end

    test "calls OwnerOnboarding.build_owner_service_info_ready/3", %{
      conn: conn,
      create_path: path,
      message_id: id,
      session: session
    } do
      decoded = %{"hello" => "service"}
      expected_response = %{"result" => "ok"}
      expect(DeviceServiceInfoReady, :decode, fn _ -> {:ok, decoded} end)

      expect(OwnerOnboarding, :build_owner_service_info_ready, fn _, _, _ ->
        {:ok, expected_response}
      end)

      request_body = Session.encrypt_and_sign(session, CBOR.encode(decoded))

      conn = post(conn, path, request_body)

      http_response = response(conn, 200)
      assert {:ok, decoded_response} = Session.decrypt_and_verify(session, http_response)
      assert decoded_response == expected_response
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a DeviceServiceInfoReady",
         %{conn: conn, create_path: path, message_id: id, session: session} do
      request_body = Session.encrypt_and_sign(session, CBOR.encode(%{bad: true}))

      conn = post(conn, path, request_body)
      assert {100, id} == assert_cbor_error(conn)
    end
  end

  describe "DeviceServiceInfo" do
    setup context do
      context = setup_authenticated(context, :service_info_end, 68)
      context
    end

    test "calls ServiceInfo.build_owner_service_info/3", %{
      conn: conn,
      create_path: path,
      message_id: id,
      session: session
    } do
      decoded = %{"hello" => "service"}
      expected_response = %{"result" => "ok"}

      expect(DeviceServiceInfo, :decode, fn _ -> {:ok, decoded} end)

      expect(ServiceInfo, :build_owner_service_info, fn _, _, _ ->
        {:ok, CBOR.encode(expected_response)}
      end)

      request_body = Session.encrypt_and_sign(session, CBOR.encode(decoded))

      conn = post(conn, path, request_body)

      http_response = response(conn, 200)
      assert {:ok, decoded_response} = Session.decrypt_and_verify(session, http_response)
      assert decoded_response == expected_response
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a DeviceServiceInfo",
         %{conn: conn, create_path: path, message_id: id, session: session} do
      request_body = Session.encrypt_and_sign(session, CBOR.encode(%{}))
      conn = post(conn, path, request_body)
      assert {100, id} == assert_cbor_error(conn)
    end
  end

  describe "Done" do
    setup context do
      setup_authenticated(context, :done, 70)
    end

    test "calls OwnerOnboarding.done/3", %{
      conn: conn,
      create_path: path,
      message_id: id,
      session: session
    } do
      expected_response = %{"result" => "finished"}
      expected_cbor_response = CBOR.encode(expected_response)

      expect(OwnerOnboarding, :done, fn _, _, _ -> {:ok, expected_cbor_response} end)

      request_body = Session.encrypt_and_sign(session, CBOR.encode(%{done: 1}))

      conn = post(conn, path, request_body)

      http_response = response(conn, 200)
      assert {:ok, decoded_response} = Session.decrypt_and_verify(session, http_response)
      assert decoded_response == expected_response
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a Done", %{
      conn: conn,
      create_path: path,
      message_id: id,
      session: session
    } do
      request_body = Session.encrypt_and_sign(session, CBOR.encode(%{}))

      conn = post(conn, path, request_body)
      assert {100, id} == assert_cbor_error(conn)
    end
  end
end
