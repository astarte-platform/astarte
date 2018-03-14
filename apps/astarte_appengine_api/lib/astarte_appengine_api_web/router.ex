#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.AppEngine.APIWeb.Router do
  use Astarte.AppEngine.APIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :swagger do
    plug :maybe_halt_swagger
  end

  scope "/v1", Astarte.AppEngine.APIWeb do
    pipe_through :api

    resources "/:realm_name/devices", DeviceStatusController, only: [:index, :show, :update]
    resources "/:realm_name/devices-by-alias", DeviceStatusByAliasController, only: [:index, :show, :update]
    resources "/:realm_name/devices/:device_id/interfaces", InterfaceValuesController, except: [:new, :edit]
    resources "/:realm_name/devices-by-alias/:device_alias/interfaces", InterfaceValuesByDeviceAliasController, except: [:new, :edit]
  end

  scope "/swagger" do
    pipe_through :swagger

    forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :astarte_appengine_api, swagger_file: "astarte_appengine_api.yaml", disable_validator: true
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
