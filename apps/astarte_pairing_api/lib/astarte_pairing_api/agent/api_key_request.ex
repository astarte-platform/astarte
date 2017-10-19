defmodule Astarte.Pairing.API.Agent.APIKeyRequest do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Pairing.API.Agent.APIKeyRequest

  embedded_schema do
    field :hw_id, :string
    field :realm, :string
  end

  @doc false
  def changeset(%APIKeyRequest{} = api_key_request, attrs) do
    api_key_request
    |> cast(attrs, [:realm, :hw_id])
    |> validate_required([:realm, :hw_id])
  end
end
