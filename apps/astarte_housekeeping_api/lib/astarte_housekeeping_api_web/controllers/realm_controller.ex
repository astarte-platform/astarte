defmodule Astarte.Housekeeping.APIWeb.RealmController do
  use Astarte.Housekeeping.APIWeb, :controller

  alias Astarte.Housekeeping.API.Realms
  alias Astarte.Housekeeping.API.Realms.Realm

  action_fallback Astarte.Housekeeping.APIWeb.FallbackController

  def index(conn, _params) do
    realms = Realms.list_realms()
    render(conn, "index.json", realms: realms)
  end

  def create(conn, realm_params = %{}) do
    with {:ok, %Realm{} = realm} <- Realms.create_realm(realm_params) do
      conn
      |> put_resp_header("location", realm_path(conn, :show, realm))
      |> send_resp(:created, "")
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, %Realm{} = realm} <- Realms.get_realm(id) do
      render(conn, "show.json", realm: realm)
    end
  end

  def update(conn, %{"id" => id, "realm" => realm_params}) do
    with {:ok, %Realm{} = realm} <- Realms.get_realm(id),
         {:ok, %Realm{} = realm} <- Realms.update_realm(realm, realm_params) do

      render(conn, "show.json", realm: realm)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, %Realm{} = realm} <- Realms.get_realm(id),
         {:ok, %Realm{}} <- Realms.delete_realm(realm) do

      send_resp(conn, :no_content, "")
    end
  end
end
