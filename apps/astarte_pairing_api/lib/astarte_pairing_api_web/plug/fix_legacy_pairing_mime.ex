defmodule Astarte.Pairing.APIWeb.Plug.FixLegacyPairingMIME do
  import Plug.Conn

  def init(_opts), do: false

  def call(conn, _opts) do
    if legacy_pairing?(conn.request_path) do
      conn
      |> put_req_header("content-type", "application/astarte-legacy-pairing")
    else
      conn
    end
  end

  defp legacy_pairing?("/api/v1/pairing"), do: true

  defp legacy_pairing?("/api/v1/verifyCertificate"), do: true

  defp legacy_pairing?(_), do: false
end
