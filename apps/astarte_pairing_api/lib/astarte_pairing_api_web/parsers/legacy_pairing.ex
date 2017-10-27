defmodule Astarte.Pairing.APIWeb.Parsers.LegacyPairing do
  @moduledoc """
  Parses legacy pairing request body and puts the csr in the body_params
  under the csr key.
  An empty request body is parsed as an empty map.
  """

  @behaviour Plug.Parsers
  import Plug.Conn

  def parse(conn, "application", "astarte-legacy-pairing", _headers, opts) do
    conn
    |> read_body(opts)
    |> decode()
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp decode({:more, _, conn}) do
    {:error, :too_large, conn}
  end

  defp decode({:error, :timeout}) do
    raise Plug.TimeoutError
  end

  defp decode({:error, _}) do
    raise Plug.BadRequestError
  end

  defp decode({:ok, "", conn}) do
    {:ok, %{}, conn}
  end

  defp decode({:ok, csr, conn}) do
    {:ok, %{"csr" => csr}, conn}
  rescue
    e -> raise Plug.Parsers.ParseError, exception: e
  end
end
