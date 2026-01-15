defmodule Astarte.AppEngine.APIWeb.Plug.AuthorizePath do
  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.APIWeb.Plug.GuardianAuthorizePath

  def init(opts) do
    GuardianAuthorizePath.init(opts)
  end

  def call(conn, opts) do
    if Config.authentication_disabled?() do
      conn
    else
      GuardianAuthorizePath.call(conn, opts)
    end
  end
end
