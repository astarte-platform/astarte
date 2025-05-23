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

defmodule Astarte.RealmManagement.APIWeb.Router do
  use Astarte.RealmManagement.APIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug Astarte.RealmManagement.APIWeb.Plug.LogRealm
    plug Astarte.RealmManagement.APIWeb.Plug.AuthorizePath
  end

  scope "/v1/:realm_name", Astarte.RealmManagement.APIWeb do
    pipe_through :api

    get "/version", VersionController, :show

    get "/interfaces/:id", InterfaceVersionController, :index
    resources "/interfaces", InterfaceController, only: [:index, :create]
    get "/interfaces/:id/:major_version", InterfaceController, :show
    put "/interfaces/:id/:major_version", InterfaceController, :update
    delete "/interfaces/:id/:major_version", InterfaceController, :delete
    get "/config/:group", RealmConfigController, :show
    put "/config/:group", RealmConfigController, :update

    resources "/triggers", TriggerController, except: [:new, :edit]
    resources "/policies", TriggerPolicyController, except: [:new, :edit]

    delete "/devices/:device_id", DeviceController, :delete
  end

  scope "/version", Astarte.RealmManagement.APIWeb do
    get "/", VersionController, :show
  end
end
