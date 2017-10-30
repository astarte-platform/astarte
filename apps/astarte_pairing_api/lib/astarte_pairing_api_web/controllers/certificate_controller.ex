defmodule Astarte.Pairing.APIWeb.CertificateController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Pairing
  alias Astarte.Pairing.API.Pairing.Certificate

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  def create(conn, %{"csr" => csr}) do
    with device_ip <- get_ip(conn),
         {:ok, api_key} <- get_api_key(conn),
         params = %{"csr" => csr, "api_key" => api_key, "device_ip" => device_ip},
         {:ok, %Certificate{} = certificate} <- Pairing.pair(params) do
      conn
      |> put_status(:created)
      |> render("show.json", certificate: certificate)
    end
  end

  defp get_api_key(conn) do
    case get_req_header(conn, "x-api-key") do
      [api_key] -> {:ok, api_key}
      [] -> {:error, :unauthorized}
    end
  end

  defp get_ip(conn) do
    conn.remote_ip
    |> :inet_parse.ntoa()
    |> to_string()
  end
end
