defmodule Astarte.Pairing.APIWeb.APIKeyController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Agent
  alias Astarte.Pairing.API.Agent.APIKey

  plug Guardian.Plug.Pipeline,
    otp_app: :astarte_pairing_api,
    module: Astarte.Pairing.APIWeb.Guardian,
    error_handler: Astarte.Pairing.APIWeb.FallbackController
  plug Guardian.Plug.VerifyHeader, realm: :none
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  def create(conn, %{"api_key" => api_key_params}) do
    with {:ok, %APIKey{} = api_key} <- Pairing.API.Agent.create_api_key(api_key_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", api_key_path(conn, :show, api_key))
      |> render("show.json", api_key: api_key)
    end
  end
end
