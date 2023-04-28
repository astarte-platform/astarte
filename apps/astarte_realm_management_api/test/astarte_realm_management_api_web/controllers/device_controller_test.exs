#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagement.APIWeb.DeviceControllerTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.RealmManagement.API.JWTTestHelper
  alias Astarte.RealmManagement.Mock

  @realm "testrealm"
  @device_id :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  @other_device_id :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

  setup %{conn: conn} do
    Mock.DB.create_device(@realm, @device_id)
    token = JWTTestHelper.gen_jwt_all_access_token()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn}
  end

  describe "delete" do
    test "deletes existing device", %{conn: conn} do
      delete_conn = delete(conn, device_path(conn, :delete, @realm, @device_id))

      assert response(delete_conn, 204)
    end

    test "renders error on non-existing device", %{conn: conn} do
      delete_conn = delete(conn, device_path(conn, :delete, @realm, @other_device_id))

      assert json_response(delete_conn, 404)["errors"] != %{}
    end
  end
end
