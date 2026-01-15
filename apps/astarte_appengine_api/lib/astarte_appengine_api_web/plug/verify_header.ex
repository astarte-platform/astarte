defmodule Astarte.AppEngine.APIWeb.Plug.VerifyHeader do
  @moduledoc """
  This is a wrapper around `Guardian.Plug.VerifyHeader` that allows to recover
  the JWT public key dynamically using information contained in the connection
  """
  import Plug.Conn

  require Logger

  alias Astarte.AppEngine.API.Auth
  alias Astarte.AppEngine.APIWeb.FallbackController
  alias Guardian.Plug.VerifyHeader, as: GuardianVerifyHeader
  alias JOSE.JWK

  def init(opts) do
    GuardianVerifyHeader.init(opts)
  end

  def call(conn, opts) do
    with {:ok, secret} <- fetch_secret(conn) do
      merged_opts =
        opts
        |> Keyword.merge(secret: secret)

      GuardianVerifyHeader.call(conn, merged_opts)
    else
      error ->
        Logger.error("Couldn't get JWT public key PEM: #{inspect(error)}.",
          tag: "get_jwt_secret_error"
        )

        conn
        |> FallbackController.call(error)
        |> halt()
    end
  end

  def fetch_secret(conn) do
    %{"realm_name" => realm} = conn.path_params

    with {:ok, public_key} <- Auth.fetch_public_key(realm) do
      {:ok, JWK.from_pem(public_key)}
    end
  end
end
