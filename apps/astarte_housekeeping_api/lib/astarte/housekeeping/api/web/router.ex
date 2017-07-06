defmodule Astarte.Housekeeping.API.Web.Router do
  use Astarte.Housekeeping.API.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", Astarte.Housekeeping.API.Web do
    pipe_through :api
  end
end
