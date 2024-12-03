# Copyright 2018-2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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
