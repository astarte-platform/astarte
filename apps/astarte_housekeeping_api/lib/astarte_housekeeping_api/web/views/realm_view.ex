defmodule Astarte.Housekeeping.API.Web.RealmView do
  use Astarte.Housekeeping.API.Web, :view
  alias Astarte.Housekeeping.API.Web.RealmView

  def render("index.json", %{realms: realms}) do
    %{data: render_many(realms, RealmView, "realm.json")}
  end

  def render("show.json", %{realm: realm}) do
    %{data: render_one(realm, RealmView, "realm.json")}
  end

  def render("realm.json", %{realm: realm}) do
    %{id: realm.id}
  end
end
