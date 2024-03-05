#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.RealmManagement.APIWeb.RealmControllerTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.RealmManagement.API.Config
  alias Astarte.RealmManagement.API.JWTTestHelper
  alias Astarte.RealmManagement.Mock.DB

  @new_pubkey """
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvO/EdyxtA8ssxSnYQr7g
  TC41/0QMvhHMqtqYSKEs1d8brOgBg51XRz1mh04v3s/k85kZq+MB4lrKzUxu0781
  MPkZpSEHU2ICD/kzE5DUDcwgvsnTBVGFX8UuGnCOICEV6rtjA+6G7Q1rEmZ017xc
  lCVz0J0EzzTzBoB1p7x56wbIDn2t7QHMkqVOIpgc+2wZqVYcxogMjGU+QcfGRFNU
  Q+qn3BHVDi5yY75LCvT8h4rvmhK30NOSVn1V8583D7uxrVY/fh/bhlMQ0AjPZo9g
  YeilQGMReWd3haRok4RT8MTThQfEJNeDZXLoZetz4ukPKInu0uE4zSAOUxkxvH6w
  MQIDAQAB
  -----END PUBLIC KEY-----
  """

  @malformed_pubkey """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYAoDQgAE6ssZpw4aj98a1hDKM
  +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
  -----END PUBLIC KEY-----
  """

  @realm "config_test_realm"
  @update_attrs %{"jwt_public_key_pem" => @new_pubkey}
  @invalid_pubkey_attrs %{"jwt_public_key_pem" => "invalid"}
  @malformed_pubkey_attrs %{"jwt_public_key_pem" => @malformed_pubkey}

  setup_all do
    # Disable the auth since we will mess with the public key
    Config.put_disable_authentication(true)

    on_exit(fn ->
      # Restore auth on exit
      Config.reload_disable_authentication()
    end)
  end

  setup %{conn: conn} do
    DB.put_jwt_public_key_pem(@realm, JWTTestHelper.public_key_pem())
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns the auth config on show", %{conn: conn} do
    conn = get(conn, realm_config_path(conn, :show, @realm, "auth"))

    assert json_response(conn, 200)["data"]["jwt_public_key_pem"] ==
             JWTTestHelper.public_key_pem()
  end

  test "does not update auth config and renders errors when no public key is provided", %{
    conn: conn
  } do
    conn = put(conn, realm_config_path(conn, :update, @realm, "auth"), data: %{})
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "does not update auth config and renders errors when public key is invalid", %{conn: conn} do
    conn =
      put(conn, realm_config_path(conn, :update, @realm, "auth"), data: @invalid_pubkey_attrs)

    assert json_response(conn, 422)["errors"] != %{}
  end

  test "does not update auth config and renders errors when public key is malformed", %{
    conn: conn
  } do
    conn =
      put(conn, realm_config_path(conn, :update, @realm, "auth"), data: @malformed_pubkey_attrs)

    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders auth config when data is valid", %{conn: conn} do
    conn = get(conn, realm_config_path(conn, :show, @realm, "auth"))

    assert json_response(conn, 200)["data"]["jwt_public_key_pem"] ==
             JWTTestHelper.public_key_pem()

    conn = put(conn, realm_config_path(conn, :update, @realm, "auth"), data: @update_attrs)
    assert response(conn, 204)

    conn = get(conn, realm_config_path(conn, :show, @realm, "auth"))
    assert json_response(conn, 200)["data"]["jwt_public_key_pem"] == @new_pubkey
  end

  test "returns the device registration limit on show", %{conn: conn} do
    limit = 10
    DB.put_device_registration_limit(@realm, limit)
    conn = get(conn, realm_config_path(conn, :show, @realm, "device_registration_limit"))

    assert json_response(conn, 200)["data"] == limit
  end

  test "returns the datastream_maximum_storage_retention on show", %{conn: conn} do
    retention = 10
    DB.put_datastream_maximum_storage_retention(@realm, retention)

    conn =
      get(conn, realm_config_path(conn, :show, @realm, "datastream_maximum_storage_retention"))

    assert json_response(conn, 200)["data"] == retention
  end
end
