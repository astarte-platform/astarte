# Copyright 2017-2023 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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
  require Logger

  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Astarte.AppEngine.APIWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(Astarte.AppEngine.APIWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :cannot_write_to_device_owned}) do
    conn
    |> put_status(:method_not_allowed)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"405_cannot_write_to_device_owned")
  end

  def call(conn, {:error, :device_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"404_device")
  end

  def call(conn, {:error, :cannot_push_to_device}) do
    conn
    |> put_status(:service_unavailable)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"503_cannot_push_to_device")
  end

  def call(conn, {:error, :endpoint_not_found}) do
    conn
    |> put_status(:bad_request)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"404_endpoint_not_found")
  end

  def call(conn, {:error, :extended_id_not_allowed}) do
    conn
    |> put_status(:bad_request)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"400")
  end

  def call(conn, {:error, :interface_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"404_interface_not_found")
  end

  def call(conn, {:error, :interface_not_in_introspection}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"404_interface_not_in_introspection")
  end

  def call(conn, {:error, :invalid_device_id}) do
    conn
    |> put_status(:bad_request)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"400")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :path_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"404_path")
  end

  def call(conn, {:error, :group_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"404_group")
  end

  def call(conn, {:error, :group_already_exists}) do
    conn
    |> put_status(:conflict)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"409_group_already_exists")
  end

  def call(conn, {:error, :device_already_in_group}) do
    conn
    |> put_status(:conflict)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"409_device_already_in_group")
  end

  def call(conn, {:error, :read_only_resource}) do
    conn
    |> put_status(:method_not_allowed)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"405_read_only_resource")
  end

  def call(conn, {:error, :unauthorized}) do
    _ = Logger.info("Refusing unauthorized request.", tag: "unauthorized")

    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"401")
  end

  def call(conn, {:error, :unexpected_value_type, expected: expected}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(
      :"422_unexpected_value_type",
      expected: expected
    )
  end

  def call(conn, {:error, :value_size_exceeded}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"422_value_size_exceeded")
  end

  def call(conn, {:error, :alias_already_in_use}) do
    conn
    |> put_status(:conflict)
    |> render(Astarte.AppEngine.APIWeb.ErrorView, :"409_alias_already_in_use")
  end

  def call(conn, {:error, :attribute_key_not_found}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"422_attribute_key_not_found")
  end

  def call(conn, {:error, :mapping_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"404_mapping_not_found")
  end

  def call(conn, {:error, :invalid_alias}) do
    conn
    |> put_status(:bad_request)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"422_invalid_alias")
  end

  def call(conn, {:error, :alias_tag_not_found}) do
    conn
    |> put_status(:bad_request)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"422_alias_tag_not_found")
  end

  def call(conn, {:error, :invalid_attributes}) do
    conn
    |> put_status(:bad_request)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"422_invalid_attributes")
  end

  def call(conn, {:error, :unexpected_object_key}) do
    conn
    |> put_status(:bad_request)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"422_unexpected_object_key")
  end

  # Invalid authorized path
  def call(conn, {:error, :invalid_auth_path}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:invalid_auth_path)
  end

  # This is called when no JWT token is present
  def auth_error(conn, {:unauthenticated, :unauthenticated}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:missing_token)
  end

  # Invalid JWT token
  def auth_error(conn, {:invalid_token, :invalid_token}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:invalid_token)
  end

  # Path not authorized
  def auth_error(conn, {:unauthorized, :authorization_path_not_matched}, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:authorization_path_not_matched, %{method: conn.method, path: conn.request_path})
  end

  def auth_error(conn, {:unauthenticated, _reason}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"401")
  end

  # In all other cases, we reply with 403
  def auth_error(conn, _reason, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(Astarte.AppEngine.APIWeb.ErrorView)
    |> render(:"403")
  end
end
