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
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.API.RealmConfig.AuthConfig do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.RealmManagement.API.RealmConfig.AuthConfig

  @required_attrs [:jwt_public_key_pem]

  @primary_key false
  embedded_schema do
    field :jwt_public_key_pem, :string
  end

  @doc false
  def changeset(%AuthConfig{} = auth_config, attrs) do
    auth_config
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> validate_pem_public_key(:jwt_public_key_pem)
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
