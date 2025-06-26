#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.PairingWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Astarte.PairingWeb, :controller
  require Logger

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(Astarte.PairingWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.PairingWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :device_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.PairingWeb.ErrorView)
    |> render(:"404_device_not_found")
  end

  def call(conn, {:error, :device_already_registered}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(Astarte.PairingWeb.ErrorView)
    |> render(:"422_device_already_registered")
  end

  def call(conn, {:error, :unauthorized}) do
    _ = Logger.info("Refusing unauthorized request.", tag: "unauthorized")

    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.PairingWeb.ErrorView)
    |> render(:"401")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(Astarte.PairingWeb.ErrorView)
    |> render(:"403")
  end

  # This is the final call made by EnsureAuthenticated
  def auth_error(conn, {:unauthenticated, reason}, _opts) do
    _ =
      Logger.info("Refusing unauthenticated request: #{inspect(reason)}.", tag: "unauthenticated")

    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.PairingWeb.ErrorView)
    |> render(:"401")
  end

  def auth_error(conn, _reason, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(Astarte.PairingWeb.ErrorView)
    |> render(:"403")
  end
end
