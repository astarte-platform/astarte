#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.PairingWeb.Router do
  use Astarte.PairingWeb, :router

  pipeline :realm_api do
    plug :accepts, ["json"]
    plug Astarte.PairingWeb.Plug.LogRealm
    plug Astarte.PairingWeb.Plug.VerifyRealmExists
  end

  pipeline :agent_api do
    plug Astarte.PairingWeb.Plug.AuthorizePath
  end

  pipeline :devices_api do
    plug Astarte.PairingWeb.Plug.LogHwId
  end

  pipeline :fdo do
    plug :accepts, ["cbor"]
    plug :put_view, Astarte.PairingWeb.FDOView
    plug Astarte.PairingWeb.Plug.SetupFDO
  end

  pipeline :fdo_session do
    plug Astarte.PairingWeb.Plug.FDOSession
  end

  pipeline :fdo_tunnel do
    plug Astarte.PairingWeb.Plug.DecryptAndVerify
  end

  scope "/v1/:realm_name", Astarte.PairingWeb do
    pipe_through :realm_api

    get "/version", VersionController, :show

    scope "/ownership" do
      pipe_through :agent_api
      post "/", OwnershipVoucherController, :create
    end

    scope "/fdo/101" do
      pipe_through :fdo

      post "/msg/60", FDOOnboardingController, :hello_device

      pipe_through :fdo_session

      post "/msg/62", FDOOnboardingController, :ov_next_entry

      pipe_through :fdo_tunnel
    end

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

  scope "/version", Astarte.PairingWeb do
    get "/", VersionController, :show
  end
end
