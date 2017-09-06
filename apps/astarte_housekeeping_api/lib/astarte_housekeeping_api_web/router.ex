defmodule Astarte.Housekeeping.API.Web.Router do
  use Astarte.Housekeeping.API.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/v1", Astarte.Housekeeping.API.Web do
    pipe_through :api

    resources "/realms", RealmController, except: [:new, :edit, :delete]
  end
end
