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

  pipeline :realm_api do
    plug :accepts, ["json"]
    plug Astarte.Pairing.APIWeb.Plug.LogRealm
  end

  pipeline :agent_api do
    plug Astarte.Pairing.APIWeb.Plug.AuthorizePath
  end

  pipeline :devices_api do
    plug Astarte.Pairing.APIWeb.Plug.LogHwId
  end

  scope "/v1/:realm_name", Astarte.Pairing.APIWeb do
    pipe_through :realm_api

    get "/version", VersionController, :show

    scope "/agent" do
      pipe_through :agent_api

      post "/devices", AgentController, :create
      delete "/devices/:device_id", AgentController, :delete
    end

    scope "/devices" do
      pipe_through :devices_api

      get "/:hw_id", DeviceController, :show_info
      post "/:hw_id/protocols/:protocol/credentials", DeviceController, :create_credentials

      post "/:hw_id/protocols/:protocol/credentials/verify",
           DeviceController,
           :verify_credentials
    end
  end

  scope "/version", Astarte.Pairing.APIWeb do
    get "/", VersionController, :show
  end
end
