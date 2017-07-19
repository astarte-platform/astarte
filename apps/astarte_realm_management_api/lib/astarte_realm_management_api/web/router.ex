defmodule Astarte.RealmManagement.API.Web.Router do
  use Astarte.RealmManagement.API.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/v1", Astarte.RealmManagement.API.Web do
    pipe_through :api

    get "/:realm_name/interfaces/:id", InterfaceVersionController, :index
    resources "/:realm_name/interfaces", InterfaceController, only: [:index, :create]
    get "/:realm_name/interfaces/:id/:major_version", InterfaceController, :show
    put "/:realm_name/interfaces/:id/:major_version", InterfaceController, :update
  end
end
