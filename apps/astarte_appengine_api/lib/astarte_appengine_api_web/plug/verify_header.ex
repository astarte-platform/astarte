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

  @no_key_errors [:missing_realm, :realm_not_found, :public_key_not_found]

  def init(opts) do
    GuardianVerifyHeader.init(opts)
  end

  def call(conn, opts) do
    case fetch_secret(conn) do
      {:ok, secret} ->
        merged_opts = Keyword.merge(opts, secret: secret)

        GuardianVerifyHeader.call(conn, merged_opts)

      error ->
        handle_secret_error(conn, error, Keyword.get(opts, :halt, true))
    end
  end

  def fetch_secret(%Plug.Conn{assigns: %{realm_name: nil}}), do: {:error, :missing_realm}

  def fetch_secret(conn) do
    with {:ok, public_key} <- Auth.fetch_public_key(conn.assigns.realm_name) do
      {:ok, JWK.from_pem(public_key)}
    end
  end

  defp handle_secret_error(conn, {:error, reason}, false) when reason in @no_key_errors, do: conn

  defp handle_secret_error(conn, error, _halt) do
    Logger.error("Couldn't get JWT public key PEM: #{inspect(error)}.",
      tag: "get_jwt_secret_error"
    )

    conn
    |> FallbackController.call(error)
    |> halt()
  end
end
