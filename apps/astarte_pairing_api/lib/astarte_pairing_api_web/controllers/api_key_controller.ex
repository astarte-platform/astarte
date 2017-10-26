defmodule Astarte.Pairing.APIWeb.APIKeyController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Agent
  alias Astarte.Pairing.API.Agent.APIKey
  alias Astarte.Pairing.API.Agent.Realm
  alias Astarte.Pairing.APIWeb.AgentGuardian

  plug Guardian.Plug.Pipeline,
    otp_app: :astarte_pairing_api,
    module: Astarte.Pairing.APIWeb.AgentGuardian,
    error_handler: Astarte.Pairing.APIWeb.FallbackController
  plug Guardian.Plug.VerifyHeader, realm: :none
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  def create(conn, %{"hwId" => hw_id}) do
    # hwId is spelled this way to preserve backwards compatibility
    with %Realm{realm_name: realm} <- AgentGuardian.Plug.current_resource(conn),
         {:ok, %APIKey{} = api_key} <- Agent.generate_api_key(%{"hw_id" => hw_id, "realm" => realm}) do
      conn
      |> put_status(:created)
      |> render("show.json", api_key)
    end
  end
end
