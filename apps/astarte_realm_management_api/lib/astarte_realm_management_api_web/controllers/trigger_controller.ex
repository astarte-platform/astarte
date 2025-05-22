#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.RealmManagement.APIWeb.TriggerController do
  use Astarte.RealmManagement.APIWeb, :controller

  alias Astarte.RealmManagement.API.Triggers
  alias Astarte.RealmManagement.API.Triggers.Trigger

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name}) do
    triggers = Triggers.list_triggers(realm_name)
    render(conn, "index.json", triggers: triggers)
  end

  def create(conn, %{"realm_name" => realm_name, "data" => trigger_params}) do
    with {:ok, %Trigger{} = trigger} <- Triggers.create_trigger(realm_name, trigger_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", trigger_path(conn, :show, realm_name, trigger))
      |> render("show.json", trigger: trigger)
    else
      {:error, :already_installed_trigger} ->
        conn
        |> put_status(:conflict)
        |> render("already_installed_trigger.json")

      {:error, :invalid_datastream_trigger} ->
        conn
        |> put_status(:bad_request)
        |> render("invalid_datastream_trigger.json")

      {:error, :unsupported_trigger_type} ->
        conn
        |> put_status(:bad_request)
        |> render("unsupported_trigger_type.json")

      {:error, :invalid_object_aggregation_trigger} ->
        conn
        |> put_status(:bad_request)
        |> render("invalid_object_aggregation_trigger.json")

      # To FallbackController
      {:error, other} ->
        {:error, other}
    end
  end

  def show(conn, %{"realm_name" => realm_name, "id" => id}) do
    with {:ok, trigger} <- Triggers.get_trigger(realm_name, id) do
      render(conn, "show.json", trigger: trigger)
    else
      {:error, :cannot_retrieve_simple_trigger} ->
        conn
        |> put_status(:internal_server_error)
        |> render("cannot_retrieve_simple_trigger.json")
    end
  end

  def update(conn, %{"realm_name" => realm_name, "id" => id, "data" => trigger_params}) do
    with {:ok, trigger} <- Triggers.get_trigger(realm_name, id),
         {:ok, %Trigger{} = updated_trigger} <-
           Triggers.update_trigger(
             realm_name,
             trigger,
             trigger_params
           ) do
      render(conn, "show.json", trigger: updated_trigger)
    end
  end

  def delete(conn, %{"realm_name" => realm_name, "id" => id}) do
    with {:ok, %Trigger{} = trigger} <- Triggers.get_trigger(realm_name, id),
         {:ok, %Trigger{}} <- Triggers.delete_trigger(realm_name, trigger) do
      send_resp(conn, :no_content, "")
    else
      {:error, :cannot_delete_simple_trigger} ->
        conn
        |> put_status(:internal_server_error)
        |> render("cannot_delete_simple_trigger.json")
    end
  end
end
