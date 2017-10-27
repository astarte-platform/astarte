defmodule Astarte.Pairing.APIWeb.CertificateView do
  use Astarte.Pairing.APIWeb, :view
  alias Astarte.Pairing.APIWeb.CertificateView

  def render("show.json", %{certificate: certificate}) do
    render_one(certificate, CertificateView, "certificate.json")
  end

  def render("certificate.json", %{certificate: certificate}) do
    # clientCrt is spelled this way for backwards compatibility
    %{clientCrt: certificate.client_crt}
  end
end
