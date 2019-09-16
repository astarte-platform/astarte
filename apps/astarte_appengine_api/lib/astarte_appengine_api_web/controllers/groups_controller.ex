#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.GroupsController do
  use Astarte.AppEngine.APIWeb, :controller

  alias Astarte.AppEngine.API.Groups
  alias Astarte.AppEngine.API.Groups.Group

  plug Astarte.AppEngine.APIWeb.Plug.AuthorizePath

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name}) do
    with {:ok, groups} <- Groups.list_groups(realm_name) do
      render(conn, "index.json", groups: groups)
    end
  end

  def create(conn, %{"realm_name" => realm_name, "data" => params}) do
    with {:ok, %Group{} = group} <- Groups.create_group(realm_name, params) do
      conn
      |> put_status(:created)
      |> render("create.json", group: group)
    end
  end
end
