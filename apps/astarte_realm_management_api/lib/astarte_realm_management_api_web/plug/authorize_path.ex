defmodule Astarte.RealmManagement.APIWeb.Plug.AuthorizePath do
  alias Astarte.RealmManagement.API.Config
  alias Astarte.RealmManagement.APIWeb.Plug.GuardianAuthorizePath

  def init(opts) do
    GuardianAuthorizePath.init(opts)
  end

  def call(conn, opts) do
    unless Config.authentication_disabled?() do
      GuardianAuthorizePath.call(conn, opts)
    else
      conn
    end
  end
end
