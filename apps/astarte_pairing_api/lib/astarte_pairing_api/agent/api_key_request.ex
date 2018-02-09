defmodule Astarte.Pairing.API.Agent.APIKeyRequest do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Pairing.API.Agent.APIKeyRequest

  @primary_key false
  embedded_schema do
    field :hw_id, :string
    field :realm, :string
  end

  @doc false
  def changeset(%APIKeyRequest{} = api_key_request, attrs) do
    api_key_request
    |> cast(attrs, [:realm, :hw_id])
    |> validate_required([:realm, :hw_id])
    |> validate_hw_id(:hw_id)
  end

  defp validate_hw_id(changeset, hw_id_key) do
    hw_id = changeset.changes[hw_id_key]

    valid =
      if is_binary(hw_id) do
        case Base.url_decode64(hw_id, padding: false) do
          {:ok, << _device_id :: binary-size(16), _extended_id :: binary-size(16) >>} -> true
          {:ok, << _device_id :: binary-size(16) >>} -> true
          _ -> false
        end
      else
        false
      end

    if valid do
      changeset
    else
      add_error(changeset, hw_id_key, "is not a valid base64 encoded 128 bits id")
    end
  end
end
