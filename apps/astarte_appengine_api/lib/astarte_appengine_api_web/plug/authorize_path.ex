defmodule Astarte.AppEngine.APIWeb.Plug.AuthorizePath do
  @moduledoc """
  Wrapper plug that conditionally enables/disables path based authorization.

  It checks the the application configuration to see if authentication is disabled.
  If disabled, it simply passes the connection through; otherwise, it delegates to the GuardianAuthorizePath.
  """
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
