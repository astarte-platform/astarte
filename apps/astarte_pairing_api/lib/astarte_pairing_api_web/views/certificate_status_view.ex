#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

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
