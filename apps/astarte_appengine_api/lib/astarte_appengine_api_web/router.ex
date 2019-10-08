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

defmodule Astarte.AppEngine.APIWeb.Router do
  use Astarte.AppEngine.APIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :swagger do
    plug :maybe_halt_swagger
  end

  scope "/v1/:realm_name", Astarte.AppEngine.APIWeb do
    pipe_through :api

    resources "/devices", DeviceStatusController, only: [:index, :show, :update]

    resources "/devices-by-alias", DeviceStatusByAliasController, only: [:index, :show, :update]

    resources "/devices/:device_id/interfaces", InterfaceValuesController, only: [:index, :show]

    get "/devices/:device_id/interfaces/:id/*path_tokens", InterfaceValuesController, :show

    put "/devices/:device_id/interfaces/:id/*path_tokens", InterfaceValuesController, :update

    post "/devices/:device_id/interfaces/:id/*path_tokens", InterfaceValuesController, :update

    delete "/devices/:device_id/interfaces/:id/*path_tokens", InterfaceValuesController, :delete

    resources "/devices-by-alias/:device_alias/interfaces",
              InterfaceValuesByDeviceAliasController,
              only: [:index, :show]

    get "/devices-by-alias/:device_alias/interfaces/:id/*path_tokens",
        InterfaceValuesByDeviceAliasController,
        :show

    put "/devices-by-alias/:device_alias/interfaces/:id/*path_tokens",
        InterfaceValuesByDeviceAliasController,
        :update

    post "/devices-by-alias/:device_alias/interfaces/:id/*path_tokens",
         InterfaceValuesByDeviceAliasController,
         :update

    delete "/devices-by-alias/:device_alias/interfaces/:id/*path_tokens",
           InterfaceValuesByDeviceAliasController,
           :delete

    get "/groups", GroupsController, :index
    post "/groups", GroupsController, :create
    get "/groups/:group_name", GroupsController, :show
    post "/groups/:group_name/devices", GroupsController, :add_device
    delete "/groups/:group_name/devices/:device_id", GroupsController, :remove_device

    get "/groups/:group_name/devices", DeviceStatusByGroupController, :index
    get "/groups/:group_name/devices/:device_id", DeviceStatusByGroupController, :show

    patch "/groups/:group_name/devices/:device_id", DeviceStatusByGroupController, :update

    get "/groups/:group_name/devices/:device_id/interfaces",
        InterfaceValuesByGroupController,
        :index

    get "/groups/:group_name/devices/:device_id/interfaces/:interface",
        InterfaceValuesByGroupController,
        :show

    get "/groups/:group_name/devices/:device_id/interfaces/:interface/*path_tokens",
        InterfaceValuesByGroupController,
        :show

    put "/groups/:group_name/devices/:device_id/interfaces/:interface/*path_tokens",
        InterfaceValuesByGroupController,
        :update

    post "/groups/:group_name/devices/:device_id/interfaces/:interface/*path_tokens",
         InterfaceValuesByGroupController,
         :update

    delete "/groups/:group_name/devices/:device_id/interfaces/:interface/*path_tokens",
           InterfaceValuesByGroupController,
           :delete
  end

  scope "/health", Astarte.AppEngine.APIWeb do
    get "/", HealthController, :show
  end

  scope "/swagger" do
    pipe_through :swagger

    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :astarte_appengine_api,
      swagger_file: "astarte_appengine_api.yaml",
      disable_validator: true
  end

  defp maybe_halt_swagger(conn, _opts) do
    if Application.get_env(:astarte_appengine_api, :swagger_ui, false) do
      conn
    else
      conn
      |> send_resp(404, "Swagger UI isn't enabled on this installation")
    end
  end
end
