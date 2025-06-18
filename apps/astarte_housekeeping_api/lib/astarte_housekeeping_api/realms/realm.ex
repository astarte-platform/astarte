#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

  alias Astarte.Housekeeping.API.Realms.NonNegativeIntegerOrUnsetType

  @default_replication_factor 1
  @default_replication_class "SimpleStrategy"

  @required_create_fields [:realm_name, :jwt_public_key_pem]
  @allowed_create_fields [
    :replication_factor,
    :replication_class,
    :datacenter_replication_factors,
    :device_registration_limit,
    :datastream_maximum_storage_retention
    | @required_create_fields
  ]

  @allowed_update_fields [
    :jwt_public_key_pem,
    :device_registration_limit,
    :datastream_maximum_storage_retention
  ]

  @primary_key false
  @derive {Phoenix.Param, key: :realm_name}

  embedded_schema do
    field :realm_name
    field :jwt_public_key_pem
    field :replication_factor, :integer
    field :replication_class, :string
    field :datacenter_replication_factors, {:map, :integer}
    field :device_registration_limit, NonNegativeIntegerOrUnsetType
    field :datastream_maximum_storage_retention, NonNegativeIntegerOrUnsetType
  end

  def changeset(realm, params \\ %{}) do
    realm
    |> cast(params, @allowed_create_fields)
    |> validate_required(@required_create_fields)
    |> validate_format(:realm_name, ~r/^[a-z][a-z0-9]*$/)
    |> validate_number(:replication_factor, greater_than: 0)
    |> validate_change(:jwt_public_key_pem, &validate_pem_public_key/2)
    |> put_default_if_missing(:replication_class, @default_replication_class)
    |> validate_inclusion(:replication_class, [
      @default_replication_class,
      "NetworkTopologyStrategy"
    ])
    |> validate_replication()
    |> maybe_put_default_replication_factor()
  end

  def update_changeset(realm, params \\ %{}) do
    realm
    |> cast(params, @allowed_update_fields)
    |> validate_change(:jwt_public_key_pem, &validate_pem_public_key/2)
  end

  def error_changeset(realm, params \\ %{}) do
    changeset =
      realm
      |> cast(params, @required_create_fields)

    %{changeset | valid?: false}
  end

  defp datacenter_map_validator(field, datacenter_map) when map_size(datacenter_map) == 0 do
    [{field, "must not be empty"}]
  end

  defp datacenter_map_validator(field, datacenter_map) do
    Enum.reduce(datacenter_map, [], fn {_datacenter_name, replication_factor}, errors_acc ->
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

      true ->
        changeset
    end
  end

  defp maybe_put_default_replication_factor(changeset) do
    replication_class = get_field(changeset, :replication_class)

    if replication_class == @default_replication_class do
      put_default_if_missing(changeset, :replication_factor, @default_replication_factor)
    else
      changeset
    end
  end

  defp validate_pem_public_key(field, pem) do
    try do
      case :public_key.pem_decode(pem) do
        [{:SubjectPublicKeyInfo, _, _}] ->
          []

        _ ->
          [{field, "is not a valid PEM public key"}]
      end
    rescue
      _ ->
        [{field, "is not a valid PEM public key"}]
    end
  end

  defp put_default_if_missing(changeset, field, default) do
    if field_missing?(changeset, field) do
      put_change(changeset, field, default)
    else
      changeset
    end
  end
end
