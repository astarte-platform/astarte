defmodule Astarte.Housekeeping.API.Realms.Realm do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:name]

  embedded_schema do
    field :name
  end

  def changeset(realm, params \\ %{}) do
    realm
    |> cast(params, @required_fields)
    |> validate_format(:name, ~r/^[a-z][a-z0-9]*$/)
  end
end
