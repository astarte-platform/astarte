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

defmodule Astarte.Pairing.API.Pairing.CertificateRequest do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Pairing.API.Pairing.CertificateRequest

  @primary_key false
  embedded_schema do
    field :api_key, :string
    field :csr, :string
    field :device_ip, :string
  end

  @doc false
  def changeset(%CertificateRequest{} = certificate_request, attrs) do
    certificate_request
    |> cast(attrs, [:csr, :api_key, :device_ip])
    |> validate_required([:csr, :api_key, :device_ip])
  end
end
