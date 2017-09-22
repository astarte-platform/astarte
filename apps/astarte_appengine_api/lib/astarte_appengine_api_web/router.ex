defmodule AstarteAppengineApiWeb.Router do
  use AstarteAppengineApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AstarteAppengineApiWeb do
    pipe_through :api
  end
end
