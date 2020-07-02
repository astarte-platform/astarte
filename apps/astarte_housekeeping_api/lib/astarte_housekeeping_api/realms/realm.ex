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

defmodule Astarte.Housekeeping.API.Realms.Realm do
  use Ecto.Schema
  import Ecto.Changeset

  @default_replication_factor 1

  @required_fields [:realm_name, :jwt_public_key_pem]
  @allowed_fields [
    :replication_factor,
    :replication_class,
    :datacenter_replication_factors
    | @required_fields
  ]

  @primary_key false
  @derive {Phoenix.Param, key: :realm_name}

  embedded_schema do
    field :realm_name
    field :jwt_public_key_pem
    field :replication_factor, :integer
    field :replication_class, :string, default: "SimpleStrategy"
    field :datacenter_replication_factors, {:map, :integer}
  end

  def changeset(realm, params \\ %{}) do
    realm
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> validate_format(:realm_name, ~r/^[a-z][a-z0-9]*$/)
    |> validate_number(:replication_factor, greater_than: 0)
    |> validate_pem_public_key(:jwt_public_key_pem)
    |> validate_inclusion(:replication_class, ["SimpleStrategy", "NetworkTopologyStrategy"])
    |> validate_replication()
  end

  def error_changeset(realm, params \\ %{}) do
    changeset =
      realm
      |> cast(params, @required_fields)

    %{changeset | valid?: false}
  end

  defp datacenter_map_validator(field, datacenter_map) when map_size(datacenter_map) == 0 do
    [{field, "must not be empty"}]
  end

  defp datacenter_map_validator(field, datacenter_map) do
    Enum.reduce(datacenter_map, [], fn {datacenter_name, replication_factor}, errors_acc ->
      if is_number(replication_factor) and replication_factor > 0 do
        errors_acc
      else
        [{field, "has invalid replication factor: #{replication_factor}"} | errors_acc]
      end
    end)
  end

  defp validate_replication(changeset) do
    replication_class = get_field(changeset, :replication_class)

    cond do
      replication_class == "NetworkTopologyStrategy" ->
        changeset
        |> validate_required(:datacenter_replication_factors,
          message: "needs to be provided with NetworkTopologyStrategy"
        )
        |> validate_change(:datacenter_replication_factors, &datacenter_map_validator/2)

      # Here we're implicitly not in NetworkTopologyStrategy
      get_field(changeset, :datacenter_replication_factors) ->
        changeset
        |> add_error(
          :datacenter_replication_factors,
          "must be used with replication_class NetworkTopologyStrategy"
        )

      get_field(changeset, :replication_factor) == nil ->
        changeset
        |> put_change(:replication_factor, @default_replication_factor)

      true ->
        changeset
    end
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
