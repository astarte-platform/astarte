defmodule Astarte.Housekeeping.API.Web.RealmController do
  use Astarte.Housekeeping.API.Web, :controller

  alias Astarte.Housekeeping.API.Realms
  alias Astarte.Housekeeping.API.Realms.Realm

  action_fallback Astarte.Housekeeping.API.Web.FallbackController

  def index(conn, _params) do
    realms = Housekeeping.API.Realms.list_realms()
    render(conn, "index.json", realms: realms)
  end

  def create(conn, %{"realm" => realm_params}) do
    with {:ok, %Realm{} = realm} <- Housekeeping.API.Realms.create_realm(realm_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", realm_path(conn, :show, realm))
      |> render("show.json", realm: realm)
    end
  end

  def show(conn, %{"id" => id}) do
    realm = Housekeeping.API.Realms.get_realm!(id)
    render(conn, "show.json", realm: realm)
  end

  def update(conn, %{"id" => id, "realm" => realm_params}) do
    realm = Housekeeping.API.Realms.get_realm!(id)

    with {:ok, %Realm{} = realm} <- Housekeeping.API.Realms.update_realm(realm, realm_params) do
      render(conn, "show.json", realm: realm)
    end
  end

  def delete(conn, %{"id" => id}) do
    realm = Housekeeping.API.Realms.get_realm!(id)
    with {:ok, %Realm{}} <- Housekeeping.API.Realms.delete_realm(realm) do
      send_resp(conn, :no_content, "")
    end
  end
end
