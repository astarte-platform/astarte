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

defmodule Astarte.AppEngine.APIWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Astarte.AppEngine.APIWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(Astarte.AppEngine.APIWeb.ChangesetView, "error.json", changeset: changeset)
  end

  def call(conn, {:error, :cannot_write_to_device_owned}) do
    conn
    |> put_status(:forbidden)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"403_cannot_write_to_device_owned.json")
  end

  def call(conn, {:error, :device_not_found}) do
    conn
    |> put_status(:not_found)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"404_device")
  end

  def call(conn, {:error, :endpoint_not_found}) do
    conn
    |> put_status(:bad_request)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"404_endpoint_not_found")
  end

  def call(conn, {:error, :extended_id_not_allowed}) do
    conn
    |> put_status(:bad_request)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"400")
  end

  def call(conn, {:error, :interface_not_found}) do
    conn
    |> put_status(:not_found)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"404_interface_not_found")
  end

  def call(conn, {:error, :interface_not_in_introspection}) do
    conn
    |> put_status(:not_found)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"404_interface_not_in_introspection")
  end

  def call(conn, {:error, :invalid_device_id}) do
    conn
    |> put_status(:bad_request)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"400")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"404")
  end

  def call(conn, {:error, :read_only_resource}) do
    conn
    |> put_status(:forbidden)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"403_read_only_resource.json")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"401")
  end

  # This is called when no JWT token is present
  def auth_error(conn, {:unauthenticated, _reason}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"401")
  end

  # In all other cases, we reply with 403
  def auth_error(conn, _reason, _opts) do
    conn
    |> put_status(:forbidden)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"403")
  end
end
