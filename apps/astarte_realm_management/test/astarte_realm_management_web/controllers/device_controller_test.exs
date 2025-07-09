#
# This file is part of Astarte.
#
# Copyright 2023 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagementWeb.DeviceControllerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.RealmManagementWeb.ConnCase
  use Astarte.Cases.Device

  @nonexisting_device_id :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

  describe "delete" do
    test "device is inserted in deletion in progress", %{
      auth_conn: conn,
      realm: realm,
      device_id: device_id
    } do
      delete_conn = delete(conn, device_path(conn, :delete, realm, device_id))

      assert response(delete_conn, 204)
    end

    test "renders error on non-existing device", %{auth_conn: conn, realm: realm} do
      delete_conn = delete(conn, device_path(conn, :delete, realm, @nonexisting_device_id))

      assert json_response(delete_conn, 404)["errors"] == %{"detail" => "Device not found"}
    end
  end
end
