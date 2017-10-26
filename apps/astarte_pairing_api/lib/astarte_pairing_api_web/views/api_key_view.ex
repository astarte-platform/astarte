defmodule Astarte.Pairing.APIWeb.APIKeyView do
  use Astarte.Pairing.APIWeb, :view
  alias Astarte.Pairing.APIWeb.APIKeyView

  def render("show.json", %{api_key: api_key}) do
    render_one(api_key, APIKeyView, "api_key.json")
  end

  def render("api_key.json", %{api_key: api_key}) do
    # apiKey is spelled this way for backwards compatibility
    %{apiKey: api_key}
  end
end
