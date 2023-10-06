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

defmodule Astarte.RealmManagement.APIWeb.DeviceController do
  use Astarte.RealmManagement.APIWeb, :controller

  alias Astarte.RealmManagement.API.Devices

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  plug Astarte.RealmManagement.APIWeb.Plug.LogRealm
  plug Astarte.RealmManagement.APIWeb.Plug.AuthorizePath

  def delete(conn, %{"realm_name" => realm_name, "device_id" => device_id}) do
    with :ok <- Devices.delete_device(realm_name, device_id) do
      send_resp(conn, :no_content, "")
    end
  end
end
