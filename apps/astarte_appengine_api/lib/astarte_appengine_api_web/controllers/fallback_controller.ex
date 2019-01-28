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

  def call(conn, {:error, :path_not_found}) do
    conn
    |> put_status(:not_found)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"404_path")
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

  def call(conn, {:error, :unexpected_value_type, expected: expected}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(
      Astarte.AppEngine.APIWeb.ErrorView,
      :"422_unexpected_value_type",
      expected: expected
    )
  end

  def call(conn, {:error, :value_size_exceeded}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"422_value_size_exceeded")
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
