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
  use Astarte.Cases.Device
  use Astarte.Cases.FDOSession
  use Mimic

  alias Astarte.FDO.Core.OwnerOnboarding.DeviceServiceInfo
  alias Astarte.FDO.Core.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.FDO.OwnerOnboarding
  alias Astarte.FDO.OwnerOnboarding.Session
  alias Astarte.FDO.ServiceInfo
  alias Astarte.Pairing.Engine

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

  defp setup_authenticated(context) do
    %{conn: conn, realm_name: realm, token: token, action: action, message_id: message_id} =
      context

    conn = put_req_header(conn, "authorization", token)

    %{
      conn: conn,
      create_path: fdo_onboarding_path(conn, action, realm),
      realm_name: realm,
      message_id: message_id
    }
  end

  describe "HelloDevice" do
    @describetag action: :hello_device
    @describetag message_id: 60

    setup :setup_authenticated

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
    @describetag action: :ov_next_entry
    @describetag message_id: 62

    setup :setup_authenticated

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
    @describetag action: :prove_device
    @describetag message_id: 64

    setup :setup_authenticated

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

    test "returns message body error when it called with something other than a ProveDevice",
         %{
           conn: conn,
           create_path: path,
           message_id: id,
           session: session
         } do
      request_body = Session.encrypt_and_sign(session, CBOR.encode(%{prove: "device"}))
      conn = post(conn, path, request_body)
      assert {100, id} == assert_cbor_error(conn)
    end
  end

  describe "DeviceServiceInfoReady" do
    @describetag action: :service_info_start
    @describetag message_id: 66

    setup :setup_authenticated

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
        {:ok, session, expected_response}
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
    @describetag action: :service_info_end
    @describetag message_id: 68

    setup :setup_authenticated

    test "calls ServiceInfo.build_owner_service_info/3 when device has more chunks", %{
      conn: conn,
      create_path: path,
      message_id: id,
      session: session
    } do
      decoded = %DeviceServiceInfo{
        is_more_service_info: true,
        service_info: %{{"devmod", "active"} => true}
      }

      expected_response = %{"result" => "ok"}

      expect(DeviceServiceInfo, :decode, fn _ -> {:ok, decoded} end)

      expect(ServiceInfo, :build_owner_service_info, fn _, _, ^decoded ->
        {:ok, CBOR.encode(expected_response)}
      end)

      request_body =
        Session.encrypt_and_sign(
          session,
          decoded |> DeviceServiceInfo.to_cbor_list() |> CBOR.encode()
        )

      conn = post(conn, path, request_body)

      http_response = response(conn, 200)
      assert {:ok, decoded_response} = Session.decrypt_and_verify(session, http_response)
      assert decoded_response == expected_response
      assert conn.assigns.message_id == id
    end

    test "calls ServiceInfo.build_owner_service_info/3 when device yields with empty service info",
         %{
           conn: conn,
           create_path: path,
           message_id: id,
           session: session
         } do
      decoded = %DeviceServiceInfo{is_more_service_info: false, service_info: %{}}
      expected_response = %{"result" => "next_owner_chunk"}

      expect(DeviceServiceInfo, :decode, fn _ -> {:ok, decoded} end)

      expect(ServiceInfo, :build_owner_service_info, fn _, _, ^decoded ->
        {:ok, CBOR.encode(expected_response)}
      end)

      request_body =
        Session.encrypt_and_sign(
          session,
          decoded |> DeviceServiceInfo.to_cbor_list() |> CBOR.encode()
        )

      conn = post(conn, path, request_body)

      http_response = response(conn, 200)
      assert {:ok, decoded_response} = Session.decrypt_and_verify(session, http_response)
      assert decoded_response == expected_response
      assert conn.assigns.message_id == id
    end

    test "creates device credentials and calls ServiceInfo.build_and_send_owner_service_info/4 on final chunk",
         context do
      %{
        conn: conn,
        device_id: device_id,
        create_path: path,
        message_id: id,
        session: session
      } = context

      decoded =
        %DeviceServiceInfo{
          is_more_service_info: false,
          service_info: %{{"devmod", "sn"} => %{"value" => "serial_number_1234"}}
        }

      expected_response = %{"result" => "ok"}
      credentials_secret = "test-credentials-secret"

      expect(DeviceServiceInfo, :decode, fn _ -> {:ok, decoded} end)

      expect(Engine, :add_unconfirmed_credentials, fn _, ^device_id ->
        {:ok, credentials_secret}
      end)

      expect(ServiceInfo, :build_and_send_owner_service_info, fn _session, ^credentials_secret ->
        {:ok, CBOR.encode(expected_response)}
      end)

      request_body =
        Session.encrypt_and_sign(
          session,
          decoded |> DeviceServiceInfo.to_cbor_list() |> CBOR.encode()
        )

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
    @describetag action: :done
    @describetag message_id: 70

    setup :setup_authenticated

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
