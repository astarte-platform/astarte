#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.Housekeeping.APIWeb.RealmController do
  use Astarte.Housekeeping.APIWeb, :controller

  alias Astarte.Housekeeping.API.Realms
  alias Astarte.Housekeeping.API.Realms.Realm

  action_fallback Astarte.Housekeeping.APIWeb.FallbackController

  def index(conn, _params) do
    realms = Realms.list_realms()
    render(conn, "index.json", realms: realms)
  end

  def create(conn, %{"data" => realm_params} = params) do
    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    with {:ok, %Realm{} = realm} <-
           Realms.create_realm(realm_params, async_operation: async_operation) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", realm_path(conn, :show, realm))
      |> render("show.json", realm: realm)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, %Realm{} = realm} <- Realms.get_realm(id) do
      render(conn, "show.json", realm: realm)
    end
  end

  def update(%Plug.Conn{method: "PATCH"} = conn, %{
        "realm_name" => realm_name,
        "data" => realm_params
      }) do
    update_params = normalize_update_attrs(realm_params)

    with {:ok, %Realm{} = updated_realm} <- Realms.update_realm(realm_name, update_params) do
      render(conn, "show.json", realm: updated_realm)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    with :ok <- Realms.delete_realm(id, async_operation: async_operation) do
      send_resp(conn, :no_content, "")
    end
  end

  defp normalize_update_attrs(update_attrs) when is_map(update_attrs) do
    update_attrs
    |> Map.replace_lazy(:device_registration_limit, &normalize_integer_or_nil/1)
    |> Map.replace_lazy("device_registration_limit", &normalize_integer_or_nil/1)
    |> Map.replace_lazy(:datastream_maximum_storage_retention, &normalize_integer_or_nil/1)
    |> Map.replace_lazy("datastream_maximum_storage_retention", &normalize_integer_or_nil/1)
  end

  defp normalize_integer_or_nil(value) when is_nil(value), do: :unset
  defp normalize_integer_or_nil(value), do: value
end
