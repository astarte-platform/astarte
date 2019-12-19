defmodule Astarte.AppEngine.APIWeb.Plug.VerifyHeader do
  @moduledoc """
  This is a wrapper around `Guardian.Plug.VerifyHeader` that allows to recover
  the JWT public key dynamically using informations contained in the connection
  """
  require Logger

  alias Astarte.AppEngine.API.Auth
  alias Guardian.Plug.VerifyHeader, as: GuardianVerifyHeader
  alias JOSE.JWK

  def init(opts) do
    GuardianVerifyHeader.init(opts)
  end

  def call(conn, opts) do
    secret = get_secret(conn)

    merged_opts =
      opts
      |> Keyword.merge(secret: secret)

    GuardianVerifyHeader.call(conn, merged_opts)
  end

  defp get_secret(conn) do
    with %{"realm_name" => realm} <- conn.path_params,
         {:ok, public_key_pem} <- Auth.fetch_public_key(realm),
         %JWK{} = jwk <- JWK.from_pem(public_key_pem) do
      jwk
    else
      error ->
        _ =
          Logger.error("Couldn't get JWT public key PEM: #{inspect(error)}.",
            tag: "get_jwt_secret_error"
          )

        nil
    end
  end
end
