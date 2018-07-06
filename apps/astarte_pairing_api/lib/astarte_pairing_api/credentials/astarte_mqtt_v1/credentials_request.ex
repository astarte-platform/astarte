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
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.Pairing.API.Credentials.AstarteMQTTV1.CredentialsRequest do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Pairing.API.Credentials.AstarteMQTTV1.CredentialsRequest

  @primary_key false
  embedded_schema do
    field :csr, :string
  end

  @doc false
  def changeset(%CredentialsRequest{} = certificate_request, attrs) do
    certificate_request
    |> cast(attrs, [:csr])
    |> validate_required([:csr])
    |> validate_pem_csr(:csr)
  end

  defp validate_pem_csr(%Ecto.Changeset{valid?: false} = changeset, _field), do: changeset

  defp validate_pem_csr(%Ecto.Changeset{} = changeset, field) do
    with {:ok, pem} <- fetch_change(changeset, field),
         {:valid_csr?, true} <- {:valid_csr?, is_valid_pem_csr?(pem)} do
      changeset
    else
      _ ->
        add_error(changeset, field, "is not a valid PEM CSR")
    end
  end

  defp is_valid_pem_csr?(pem) do
    try do
      case :public_key.pem_decode(pem) do
        [{:CertificationRequest, _, _}] ->
          true

        _ ->
          false
      end
    rescue
      _ ->
        false
    end
  end
end
