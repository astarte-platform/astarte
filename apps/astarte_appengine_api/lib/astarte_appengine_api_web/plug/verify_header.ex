defmodule Astarte.AppEngine.APIWeb.Plug.VerifyHeader do
  @moduledoc """
  This is a wrapper around `Guardian.Plug.VerifyHeader` that allows to recover
  the JWT public key dynamically using informations contained in the connection
  """

  alias Astarte.AppEngine.API.Auth

  def init(opts) do
    Guardian.Plug.VerifyHeader.init(opts)
  end

  def call(conn, opts) do
    secret = get_secret(conn)

    merged_opts =
      opts
      |> Keyword.merge([secret: secret])

    Guardian.Plug.VerifyHeader.call(conn, merged_opts)
  end

  defp get_secret(conn) do
    with %{"realm_name" => realm} <- conn.path_params,
         {:ok, public_key_pem} <- Auth.fetch_public_key(realm),
         %JOSE.JWK{} = jwk <- JOSE.JWK.from_pem(public_key_pem) do
      jwk
    else
      _ ->
        nil
    end
  end
end
