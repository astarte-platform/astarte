defmodule AstarteRealmManagementApi.Web.Router do
  use AstarteRealmManagementApi.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AstarteRealmManagementApi.Web do
    pipe_through :api
  end
end
