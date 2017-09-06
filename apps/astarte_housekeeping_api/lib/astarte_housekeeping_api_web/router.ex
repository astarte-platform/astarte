defmodule Astarte.Housekeeping.APIWeb.Router do
  use Astarte.Housekeeping.APIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/v1", Astarte.Housekeeping.APIWeb do
    pipe_through :api

    resources "/realms", RealmController, except: [:new, :edit, :delete]
  end
end
