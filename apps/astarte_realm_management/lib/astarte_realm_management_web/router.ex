#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagementWeb.Router do
  use Astarte.RealmManagementWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug Astarte.RealmManagementWeb.Plug.LogRealm
    plug Astarte.RealmManagementWeb.Plug.VerifyRealmExists
    plug Astarte.RealmManagementWeb.Plug.AuthorizePath
  end

  scope "/v1/:realm_name", Astarte.RealmManagementWeb do
    pipe_through :api

    get "/version", VersionController, :show_with_realm

    get "/interfaces/:interface_name", InterfaceVersionController, :index
    resources "/interfaces", InterfaceController, only: [:index, :create]
    get "/interfaces/:interface_name/:major_version", InterfaceController, :show
    put "/interfaces/:interface_name/:major_version", InterfaceController, :update
    delete "/interfaces/:interface_name/:major_version", InterfaceController, :delete
    get "/config/auth", RealmConfigController, :show_auth
    put "/config/auth", RealmConfigController, :update_auth

    get "/config/device_registration_limit",
        RealmConfigController,
        :show_device_registration_limit

    get "/config/datastream_maximum_storage_retention",
        RealmConfigController,
        :show_datastream_maximum_storage_retention

    resources "/triggers", TriggerController,
      except: [:new, :edit, :update],
      param: "trigger_name"

    resources "/policies", TriggerPolicyController,
      except: [:new, :edit, :update],
      param: "policy_name"

    delete "/devices/:device_id", DeviceController, :delete
  end

  scope "/version", Astarte.RealmManagementWeb do
    get "/", VersionController, :show
  end
end
