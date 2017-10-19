defmodule Astarte.Pairing.APIWeb.APIKeyController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Agent
  alias Astarte.Pairing.API.Agent.APIKey

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  def index(conn, _params) do
    api_keys = Pairing.API.Agent.list_api_keys()
    render(conn, "index.json", api_keys: api_keys)
  end

  def create(conn, %{"api_key" => api_key_params}) do
    with {:ok, %APIKey{} = api_key} <- Pairing.API.Agent.create_api_key(api_key_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", api_key_path(conn, :show, api_key))
      |> render("show.json", api_key: api_key)
    end
  end

  def show(conn, %{"id" => id}) do
    api_key = Pairing.API.Agent.get_api_key!(id)
    render(conn, "show.json", api_key: api_key)
  end

  def update(conn, %{"id" => id, "api_key" => api_key_params}) do
    api_key = Pairing.API.Agent.get_api_key!(id)

    with {:ok, %APIKey{} = api_key} <- Pairing.API.Agent.update_api_key(api_key, api_key_params) do
      render(conn, "show.json", api_key: api_key)
    end
  end

  def delete(conn, %{"id" => id}) do
    api_key = Pairing.API.Agent.get_api_key!(id)
    with {:ok, %APIKey{}} <- Pairing.API.Agent.delete_api_key(api_key) do
      send_resp(conn, :no_content, "")
    end
  end
end
