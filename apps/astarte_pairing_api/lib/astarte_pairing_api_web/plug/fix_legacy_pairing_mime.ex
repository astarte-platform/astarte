defmodule Astarte.Pairing.APIWeb.Plug.FixLegacyPairingMIME do
  import Plug.Conn

  def init(_opts), do: false

  def call(conn, _opts) do
    if legacy_pairing?(conn) do
      conn
      |> put_req_header("content-type", "application/astarte-legacy-pairing")
    else
      conn
    end
  end

  defp legacy_pairing?(conn) do
    conn.request_path == "/api/v1/pairing"
  end
end
