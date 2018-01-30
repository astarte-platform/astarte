defmodule Astarte.Housekeeping.API.Realms.Realm do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:realm_name, :jwt_public_key_pem]

  @primary_key false
  @derive {Phoenix.Param, key: :realm_name}

  embedded_schema do
    field :realm_name
    field :jwt_public_key_pem
  end

  def changeset(realm, params \\ %{}) do
    realm
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> validate_format(:realm_name, ~r/^[a-z][a-z0-9]*$/)
    |> validate_pem_public_key(:jwt_public_key_pem)
  end

  def error_changeset(realm, params \\ %{}) do
    changeset = realm
      |> cast(params, @required_fields)

    %{changeset | valid?: false}
  end

  defp validate_pem_public_key(%Ecto.Changeset{valid?: false} = changeset, _field), do: changeset

  defp validate_pem_public_key(changeset, field) do
    pem = get_field(changeset, field, "")
    try do
      case :public_key.pem_decode(pem) do
        [{:SubjectPublicKeyInfo, _, _}] ->
          changeset

        _ ->
          changeset
          |> add_error(field, "is not a valid PEM public key")
      end
    rescue
      _ ->
        changeset
        |> add_error(field, "is not a valid PEM public key")
    end
  end
end
