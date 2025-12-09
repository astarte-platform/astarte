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
  use Mimic

  alias Astarte.Pairing.FDO.OwnerOnboarding
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.ServiceInfo

  import Astarte.Helpers.FDO

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
    %{conn: conn, realm_name: realm} = context

    conn =
      conn
      |> put_req_header("authorization", "mock_session_key")

    stub(Session, :fetch, fn ^realm, "mock_session_key" ->
      {:ok, %{device_id: sample_device_guid()}}
    end)

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
      # FIXME this should return error 100?
      assert {500, id} == assert_cbor_error(conn)
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
      # FIXME this should return error 100?
      assert {500, id} == assert_cbor_error(conn)
    end
  end

  describe "ProveDevice" do
    setup context do
      setup_authenticated(context, :prove_device, 64)
    end

    test "calls `OwnerOnboarding.prove_device/3`", %{
      conn: conn,
      create_path: path,
      message_id: id
    } do
      expected_response = %{"result" => true}
      session_map = %{device_id: "device123", session_info: "mock"}

      expect(OwnerOnboarding, :prove_device, fn _, _, _ ->
        {:ok, session_map, expected_response}
      end)

      stub(Session, :encrypt_and_sign, fn _, cbor -> cbor end)

      conn = post(conn, path, CBOR.encode(%{prove: "device"}))
      assert cbor_response(conn) == expected_response
      assert conn.assigns.to2_session == session_map
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a ProveDevice", %{
      conn: conn,
      create_path: path,
      message_id: id
    } do
      conn = post(conn, path, CBOR.encode(%{prove: "device"}))
      # FIXME this should return error 100?
      assert {500, id} == assert_cbor_error(conn)
    end
  end

  describe "DeviceServiceInfoReady" do
    setup context do
      context = setup_authenticated(context, :service_info_start, 66)
      # TODO make direct call for decrypt_and_verify
      stub(Session, :decrypt_and_verify, fn _, body -> {:ok, body} end)
      context
    end

    test "calls ServiceInfo.handle_msg_66/3", %{
      conn: conn,
      create_path: path,
      message_id: id
    } do
      decoded = %{hello: "service"}
      expected_response = %{"result" => "ok"}
      # TODO make direct call for decode
      expect(DeviceServiceInfoReady, :decode, fn _ -> {:ok, decoded} end)

      expect(ServiceInfo, :handle_msg_66, fn _, _, _ ->
        {:ok, expected_response}
      end)

      # TODO make direct call for encrypt_and_sign
      stub(Session, :encrypt_and_sign, fn _, cbor -> cbor end)

      conn = post(conn, path, CBOR.encode(decoded))
      assert cbor_response(conn) == expected_response
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a DeviceServiceInfoReady",
         %{conn: conn, create_path: path, message_id: id} do
      conn = post(conn, path, CBOR.encode(%{bad: true}))
      assert {100, id} == assert_cbor_error(conn)
    end
  end

  describe "DeviceServiceInfo" do
    setup context do
      context = setup_authenticated(context, :service_info_end, 68)
      # TODO make direct call for decrypt_and_verify
      stub(Session, :decrypt_and_verify, fn _, body -> {:ok, body} end)
      context
    end

    test "calls ServiceInfo.handle_message_68/3", %{
      conn: conn,
      create_path: path,
      message_id: id
    } do
      decoded = %{hello: "service"}
      expected_response = %{"result" => "ok"}

      # TODO make direct call for decode
      expect(DeviceServiceInfo, :decode, fn _ -> {:ok, decoded} end)

      expect(ServiceInfo, :handle_message_68, fn _, _, _ ->
        {:ok, CBOR.encode(expected_response)}
      end)

      # TODO make direct call for encrypt_and_sign
      stub(Session, :encrypt_and_sign, fn _, cbor -> cbor end)

      conn = post(conn, path, CBOR.encode(decoded))
      assert cbor_response(conn) == expected_response
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a DeviceServiceInfo",
         %{conn: conn, create_path: path, message_id: id} do
      conn = post(conn, path, CBOR.encode(%{}))
      assert {100, id} == assert_cbor_error(conn)
    end
  end

  describe "Done" do
    setup context do
      setup_authenticated(context, :done, 70)
    end

    test "calls OwnerOnboarding.done/2", %{conn: conn, create_path: path, message_id: id} do
      expected_response = %{"result" => "finished"}

      expect(OwnerOnboarding, :done, fn _, _ -> {:ok, expected_response} end)

      # TODO make direct call for encrypt_and_sign and decrypt_and_verify
      stub(Session, :encrypt_and_sign, fn _, map -> CBOR.encode(map) end)
      stub(Session, :decrypt_and_verify, fn _, body -> {:ok, body} end)

      conn = post(conn, path, CBOR.encode(%{done: 1}))
      assert cbor_response(conn) == expected_response
      assert conn.assigns.message_id == id
    end

    test "returns message body error when it called with something other than a Done", %{
      conn: conn,
      create_path: path,
      message_id: id
    } do
      # TODO make direct call for decrypt_and_verify
      stub(Session, :decrypt_and_verify, fn _, body -> {:ok, body} end)

      conn = post(conn, path, CBOR.encode(%{}))
      assert {100, id} == assert_cbor_error(conn)
    end
  end
end
