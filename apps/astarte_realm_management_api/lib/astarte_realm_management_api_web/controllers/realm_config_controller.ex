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

defmodule Astarte.RealmManagement.APIWeb.RealmConfigController do
  use Astarte.RealmManagement.APIWeb, :controller

  alias Astarte.RealmManagement.API.RealmConfig
  alias Astarte.RealmManagement.API.RealmConfig.AuthConfig

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  plug Astarte.RealmManagement.APIWeb.Plug.LogRealm
  plug Astarte.RealmManagement.APIWeb.Plug.AuthorizePath

  def show(conn, %{"realm_name" => realm_name, "group" => "auth"}) do
    with {:ok, %AuthConfig{} = auth_config} = RealmConfig.get_auth_config(realm_name) do
      render(conn, "show.json", auth_config: auth_config)
    end
  end

  def show(conn, %{"realm_name" => realm_name, "group" => "device_registration_limit"}) do
    with {:ok, device_registration_limit} = RealmConfig.get_device_registration_limit(realm_name) do
      render(conn, "show.json", device_registration_limit: device_registration_limit)
    end
  end

  def update(conn, %{"realm_name" => realm_name, "group" => "auth", "data" => new_config}) do
    with :ok <- RealmConfig.update_auth_config(realm_name, new_config) do
      send_resp(conn, :no_content, "")
    end
  end
end
