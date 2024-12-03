defmodule Astarte.Test.Cases.Conn do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Astarte.AppEngine.APIWeb.Router.Helpers

      # The default endpoint for testing
      @endpoint Astarte.AppEngine.APIWeb.Endpoint
    end
  end

  alias Astarte.Test.Setups.Conn, as: ConnSetup

  setup_all [
    {ConnSetup, :create_conn},
    {ConnSetup, :jwt},
    {ConnSetup, :auth_conn}
  ]
end
