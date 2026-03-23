#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Secrets.OwnerKeyInitializationOptions do
  @moduledoc """
  Schema and validation for owner key upload/creation options in Astarte API.
  Defines the parameters that can be used when requesting creation or upload of an owner key in OpenBao.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Astarte.Secrets.OwnerKeyInitializationOptions

  @allowed_key_algorithms ["ecdsa-p256", "ecdsa-p384", "rsa-2048", "rsa-3072"]

  embedded_schema do
    field(:action, :string)
    field(:key_name, :string)
    field(:key_data, :string)
    field(:key_algorithm, :string)
  end

  @doc false
  def changeset(%OwnerKeyInitializationOptions{} = owner_key_request, attrs) do
    cast_attrs = [
      :action,
      :key_name,
      :key_data,
      :key_algorithm
    ]

    required_attrs = [
      :action,
      :key_name
    ]

    owner_key_request
    |> cast(attrs, cast_attrs)
    |> validate_required(required_attrs)
    |> validate_inclusion(:action, ["create", "upload"])
    |> validate_conditional_attrs()
  end

  # key creation and upload require different parameters
  defp validate_conditional_attrs(changeset) do
    case get_change(changeset, :action) do
      "create" ->
        changeset
        |> validate_required(:key_algorithm)
        |> validate_inclusion(:key_algorithm, @allowed_key_algorithms)

      "upload" ->
        changeset
        |> validate_required(:key_data)

      _ ->
        changeset
    end
  end
end
