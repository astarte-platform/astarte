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

defmodule Astarte.Pairing.APIWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Astarte.Pairing.APIWeb, :controller
  require Logger

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(Astarte.Pairing.APIWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.Pairing.APIWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :device_not_found}) do
    conn
    |> put_status(:not_found)
    |> render(Astarte.Pairing.APIWeb.ErrorView, :"404_device_not_found")
  end

  def call(conn, {:error, :unauthorized}) do
    _ = Logger.info("Refusing unauthorized request.", tag: "unauthorized")

    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.Pairing.APIWeb.ErrorView)
    |> render(:"401")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(Astarte.Pairing.APIWeb.ErrorView)
    |> render(:"403")
  end

  # Invalid authorized path
  def call(conn, {:error, :invalid_auth_path}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.Pairing.APIWeb.ErrorView)
    |> render(:invalid_auth_path)
  end

  # This is called when no JWT token is present
  def auth_error(conn, {:unauthenticated, :unauthenticated}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.Pairing.APIWeb.ErrorView)
    |> render(:missing_token)
  end

  # Invalid JWT token
  def auth_error(conn, {:invalid_token, :invalid_token}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.Pairing.APIWeb.ErrorView)
    |> render(:invalid_token)
  end

  # Path not authorized
  def auth_error(conn, {:unauthorized, :authorization_path_not_matched}, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(Astarte.Pairing.APIWeb.ErrorView)
    |> render(:authorization_path_not_matched, %{method: conn.method, path: conn.request_path})
  end

  def auth_error(conn, {:unauthenticated, _reason}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.Pairing.APIWeb.ErrorView)
    |> render(:"401")
  end

  # In all other cases, we reply with 403
  def auth_error(conn, _reason, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(Astarte.Pairing.APIWeb.ErrorView)
    |> render(:"403")
  end
end
