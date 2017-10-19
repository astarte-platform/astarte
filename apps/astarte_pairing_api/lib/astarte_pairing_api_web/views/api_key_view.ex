defmodule Astarte.Pairing.APIWeb.APIKeyView do
  use Astarte.Pairing.APIWeb, :view
  alias Astarte.Pairing.APIWeb.APIKeyView

  def render("index.json", %{api_keys: api_keys}) do
    %{data: render_many(api_keys, APIKeyView, "api_key.json")}
  end

  def render("show.json", %{api_key: api_key}) do
    %{data: render_one(api_key, APIKeyView, "api_key.json")}
  end

  def render("api_key.json", %{api_key: api_key}) do
    %{id: api_key.id}
  end
end
