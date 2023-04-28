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
  end

  scope "/v1", Astarte.RealmManagement.APIWeb do
    pipe_through :api

    get "/:realm_name/version", VersionController, :show

    get "/:realm_name/interfaces/:id", InterfaceVersionController, :index
    resources "/:realm_name/interfaces", InterfaceController, only: [:index, :create]
    get "/:realm_name/interfaces/:id/:major_version", InterfaceController, :show
    put "/:realm_name/interfaces/:id/:major_version", InterfaceController, :update
    delete "/:realm_name/interfaces/:id/:major_version", InterfaceController, :delete
    get "/:realm_name/config/:group", RealmConfigController, :show
    put "/:realm_name/config/:group", RealmConfigController, :update

    resources "/:realm_name/triggers", TriggerController, except: [:new, :edit]
    resources "/:realm_name/policies", TriggerPolicyController, except: [:new, :edit]

    delete "/:realm_name/devices/:device_id", DeviceController, :delete
  end
end
