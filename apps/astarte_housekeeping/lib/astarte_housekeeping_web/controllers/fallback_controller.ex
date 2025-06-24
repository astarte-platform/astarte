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

defmodule Astarte.HousekeepingWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Astarte.HousekeepingWeb, :controller

  alias Astarte.HousekeepingWeb.ChangesetView
  alias Astarte.HousekeepingWeb.ErrorView

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :database_connection_error}) do
    conn
    |> put_status(:service_unavailable)
    |> put_view(ErrorView)
    |> render(:"503")
  end

  def call(conn, {:error, :database_error}) do
    conn
    |> put_status(:service_unavailable)
    |> put_view(ErrorView)
    |> render(:"503")
  end

  def call(conn, {:error, :realm_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(ErrorView)
    |> render(:realm_not_found)
  end

  def call(conn, {:error, :realm_deletion_disabled}) do
    conn
    |> put_status(:method_not_allowed)
    |> put_view(ErrorView)
    |> render(:realm_deletion_disabled)
  end

  def call(conn, {:error, :connected_devices_present}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ErrorView)
    |> render(:connected_devices_present)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :delete_datastream_maximum_storage_retention_fail}) do
    conn
    |> put_status(:service_unavailable)
    |> put_view(ErrorView)
    |> render(:"503")
  end

  def call(conn, {:error, :set_datastream_maximum_storage_retention_fail}) do
    conn
    |> put_status(:service_unavailable)
    |> put_view(ErrorView)
    |> render(:"503")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(ErrorView)
    |> render(:"401")
  end

  # This is called when no JWT token is present
  def auth_error(conn, {:unauthenticated, _reason}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(ErrorView)
    |> render(:"401")
  end

  # In all other cases, we reply with 403
  def auth_error(conn, _reason, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(ErrorView)
    |> render(:"403")
  end
end
