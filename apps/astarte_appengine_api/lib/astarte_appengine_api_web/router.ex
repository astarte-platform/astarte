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
  alias Astarte.AppEngine.APIWeb.Plug.LogRealm

  pipeline :realm_api do
    plug :accepts, ["json"]
    plug LogRealm
    plug Astarte.AppEngine.APIWeb.Plug.AuthorizePath
  end

  pipeline :device_api do
    plug Astarte.AppEngine.APIWeb.Plug.LogDeviceId
  end

  pipeline :device_group_api do
    plug Astarte.AppEngine.APIWeb.Plug.GroupNameDecoder
    plug Astarte.AppEngine.APIWeb.Plug.LogGroupName
  end

  pipeline :device_alias_api do
    plug Astarte.AppEngine.APIWeb.Plug.LogDeviceAlias
  end

  pipeline :interface_value_api do
    plug Astarte.AppEngine.APIWeb.Plug.JoinPath
    plug Astarte.AppEngine.APIWeb.Plug.LogInterface
    plug Astarte.AppEngine.APIWeb.Plug.LogPath
  end

  pipeline :swagger do
    plug :maybe_halt_swagger
  end

  scope "/v1/:realm_name", Astarte.AppEngine.APIWeb do
    pipe_through :realm_api

    get "/version", VersionController, :show

    scope "/stats" do
      get "/devices", StatsController, :show_devices_stats
    end

    scope "/devices" do
      pipe_through :device_api

      resources "/", DeviceStatusController,
        only: [:index, :show, :update],
        param: "device_id"

      scope "/:device_id/interfaces" do
        pipe_through :interface_value_api

        resources "/", InterfaceValuesController,
          only: [:index, :show],
          param: "interface"

        get "/:interface/*path_tokens", InterfaceValuesController, :show

        put "/:interface/*path_tokens",
            InterfaceValuesController,
            :update

        post "/:interface/*path_tokens",
             InterfaceValuesController,
             :update

        delete "/:interface/*path_tokens",
               InterfaceValuesController,
               :delete
      end
    end

    scope "/devices-by-alias" do
      pipe_through :device_alias_api

      resources "/", DeviceStatusByAliasController,
        only: [:index, :show, :update],
        param: "device_alias"

      scope "/:device_alias/interfaces" do
        pipe_through :interface_value_api

        resources "/",
                  InterfaceValuesByDeviceAliasController,
                  only: [:index, :show],
                  param: "interface"

        get "/:interface/*path_tokens",
            InterfaceValuesByDeviceAliasController,
            :show

        put "/:interface/*path_tokens",
            InterfaceValuesByDeviceAliasController,
            :update

        post "/:interface/*path_tokens",
             InterfaceValuesByDeviceAliasController,
             :update

        delete "/:interface/*path_tokens",
               InterfaceValuesByDeviceAliasController,
               :delete
      end
    end

    scope "/groups" do
      pipe_through :device_group_api

      get "/", GroupsController, :index
      post "/", GroupsController, :create

      scope "/:group_name" do
        get "/", GroupsController, :show
        get "/devices", DeviceStatusByGroupController, :index
        post "/devices", GroupsController, :add_device

        scope "/devices/:device_id" do
          pipe_through :device_api

          get "/", DeviceStatusByGroupController, :show
          patch "/", DeviceStatusByGroupController, :update
          delete "/", GroupsController, :remove_device

          scope "/interfaces" do
            pipe_through :interface_value_api

            get "/",
                InterfaceValuesByGroupController,
                :index

            get "/:interface",
                InterfaceValuesByGroupController,
                :show

            get "/:interface/*path_tokens",
                InterfaceValuesByGroupController,
                :show

            put "/:interface/*path_tokens",
                InterfaceValuesByGroupController,
                :update

            post "/:interface/*path_tokens",
                 InterfaceValuesByGroupController,
                 :update

            delete "/:interface/*path_tokens",
                   InterfaceValuesByGroupController,
                   :delete
          end
        end
      end
    end
  end

  scope "/swagger" do
    pipe_through :swagger

    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :astarte_appengine_api,
      swagger_file: "astarte_appengine_api.yaml",
      disable_validator: true
  end

  scope "/version", Astarte.AppEngine.APIWeb do
    get "/", VersionController, :show
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
