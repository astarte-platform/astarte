defmodule Astarte.Housekeeping.APIWeb.RealmView do
  use Astarte.Housekeeping.APIWeb, :view
  alias Astarte.Housekeeping.APIWeb.RealmView

  def render("index.json", %{realms: realms}) do
    render_many(realms, RealmView, "realm_name_only.json")
  end

  def render("show.json", %{realm: realm}) do
    render_one(realm, RealmView, "realm.json")
  end

  def render("realm_name_only.json", %{realm: realm}) do
    realm.realm_name
  end

  def render("realm.json", %{realm: realm}) do
    %{realm_name: realm.realm_name}
  end
end
