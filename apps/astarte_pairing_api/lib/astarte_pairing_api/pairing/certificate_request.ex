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
