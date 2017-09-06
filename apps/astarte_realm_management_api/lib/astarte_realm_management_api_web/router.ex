defmodule Astarte.RealmManagement.APIWeb.Router do
  use Astarte.RealmManagement.APIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/v1", Astarte.RealmManagement.APIWeb do
    pipe_through :api

    get "/:realm_name/interfaces/:id", InterfaceVersionController, :index
    resources "/:realm_name/interfaces", InterfaceController, only: [:index, :create]
    get "/:realm_name/interfaces/:id/:major_version", InterfaceController, :show
    put "/:realm_name/interfaces/:id/:major_version", InterfaceController, :update
    delete "/:realm_name/interfaces/:id/:major_version", InterfaceController, :delete
  end
end
