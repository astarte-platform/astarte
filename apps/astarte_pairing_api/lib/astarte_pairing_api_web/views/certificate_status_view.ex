defmodule Astarte.Pairing.APIWeb.CertificateStatusView do
  use Astarte.Pairing.APIWeb, :view
  alias Astarte.Pairing.APIWeb.CertificateStatusView

  def render("show.json", %{certificate_status: certificate_status}) do
    render_one(certificate_status, CertificateStatusView, "certificate.json")
  end

  def render("certificate.json", %{certificate_status: %{valid: true} = certificate_status}) do
    # clientCrt is spelled this way for backwards compatibility
    %{valid: certificate_status.valid,
      timestamp: certificate_status.timestamp,
      until: certificate_status.until}
  end

  def render("certificate.json", %{certificate_status: %{valid: false} = certificate_status}) do
    # clientCrt is spelled this way for backwards compatibility
    %{valid: certificate_status.valid,
      timestamp: certificate_status.timestamp,
      cause: certificate_status.cause,
      details: certificate_status.details}
  end
end
