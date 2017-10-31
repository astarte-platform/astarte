defmodule Astarte.Pairing.APIWeb.Router do
  use Astarte.Pairing.APIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", Astarte.Pairing.APIWeb do
    pipe_through :api

    post "/verifyCertificate", CertificateController, :verify
    post "/pairing", CertificateController, :create
    post "/devices/apikeysFromDevice", APIKeyController, :create
    get "/info", BrokerInfoController, :show
  end
end
