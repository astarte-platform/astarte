defmodule Astarte.Pairing.API.Pairing.VerifyCertificateRequest do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Pairing.API.Pairing.VerifyCertificateRequest

  @primary_key false
  embedded_schema do
    field :certificate, :string
  end

  @doc false
  def changeset(%VerifyCertificateRequest{} = certificate_request, attrs) do
    certificate_request
    |> cast(attrs, [:certificate])
    |> validate_required([:certificate])
  end
end
