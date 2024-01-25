#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.Pairing.APIWeb.Router do
  use Astarte.Pairing.APIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug Astarte.Pairing.APIWeb.Plug.LogRealm
  end

  scope "/v1/:realm_name", Astarte.Pairing.APIWeb do
    pipe_through :api

    get "/version", VersionController, :show

    post "/agent/devices", AgentController, :create
    delete "/agent/devices/:device_id", AgentController, :delete

    get "/devices/:hw_id", DeviceController, :show_info

    post "/devices/:hw_id/protocols/:protocol/credentials", DeviceController, :create_credentials

    post "/devices/:hw_id/protocols/:protocol/credentials/verify",
         DeviceController,
         :verify_credentials
  end

  scope "/version", Astarte.Pairing.APIWeb do
    get "/", VersionController, :show
  end
end
