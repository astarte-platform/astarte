#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Pairing.Credentials.AstarteMQTTV1.CredentialsRequest do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Pairing.Credentials.AstarteMQTTV1.CredentialsRequest

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
