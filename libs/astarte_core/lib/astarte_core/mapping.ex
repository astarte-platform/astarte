#
# This file is part of Astarte.
#
# Copyright 2017-2024 SECO Mind Srl
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

defmodule Astarte.Core.Mapping do
  @moduledoc """
  This module handles Interface Mappings using Ecto Changesets
  """
  use TypedEctoSchema
  import Ecto.Changeset
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.DatabaseRetentionPolicy
  alias Astarte.Core.Mapping.Reliability
  alias Astarte.Core.Mapping.Retention
  alias Astarte.Core.Mapping.ValueType

  @placeholder_regex ~r/%{[a-zA-Z_]+[a-zA-Z0-9_]*}/

  @required_fields [
    :endpoint,
    :type
  ]
  @permitted_fields [
    :reliability,
    :retention,
    :expiry,
    :database_retention_policy,
    :database_retention_ttl,
    :allow_unset,
    :explicit_timestamp,
    :description,
    :doc,
    :path,
    :required
    | @required_fields
  ]

  @primary_key false
  typed_embedded_schema do
    field :endpoint
    field :value_type, ValueType
    field :reliability, Reliability, default: :unreliable
    field :retention, Retention, default: :discard
    field :expiry, :integer, default: 0
    field :database_retention_policy, DatabaseRetentionPolicy, default: :no_ttl
    field :database_retention_ttl, :integer, default: nil
    field :allow_unset, :boolean, default: false
    field :explicit_timestamp, :boolean, default: false
    field :description
    field :doc
    field :endpoint_id, :binary
    field :interface_id, :binary
    field :required, :boolean, default: false
    # Legacy support
    field :path, :string, virtual: true
    # Different input naming
    field :type, ValueType, virtual: true
  end

  def changeset(%Mapping{} = mapping, %{} = params, opts) do
    # We need those, so we raise if they're not there
    # Note that they can be there but be nil,
    # but this would be handled from the parent changeset
    interface_name = Keyword.fetch!(opts, :interface_name)
    interface_major = Keyword.fetch!(opts, :interface_major)
    interface_id = Keyword.fetch!(opts, :interface_id)
    interface_type = Keyword.get(opts, :interface_type)
    interface_aggregation = Keyword.get(opts, :interface_aggregation)

    mapping
    |> cast(params, @permitted_fields)
    |> handle_legacy_endpoint()
    |> validate_required(@required_fields)
    |> validate_length(:endpoint, min: 2, max: 256)
    |> validate_format(:endpoint, mapping_regex())
    |> validate_number(:expiry, greater_than_or_equal_to: 0)
    |> validate_number(:database_retention_ttl,
      greater_than_or_equal_to: 60,
      less_than: 20 * 365 * 24 * 60 * 60
    )
    |> validate_not_set_unless(:allow_unset, interface_type, [:properties, nil])
    |> validate_not_set_unless(:expiry, interface_type, [:datastream, nil])
    |> validate_not_set_unless(:retention, interface_type, [:datastream, nil])
    |> validate_not_set_unless(:reliability, interface_type, [:datastream, nil])
    |> validate_not_set_unless(:database_retention_policy, interface_type, [:datastream, nil])
    |> validate_not_set_unless(:database_retention_ttl, interface_type, [:datastream, nil])
    |> validate_not_set_unless(:explicit_timestamp, interface_type, [:datastream, nil])
    |> validate_not_set_unless(:required, interface_aggregation, [:object, nil])
    |> validate_length(:description, max: 1000)
    |> validate_length(:doc, max: 100_000)
    |> validate_database_retention_policy_and_ttl()
    |> normalize_fields()
    |> put_change(:interface_id, interface_id)
    |> put_endpoint_id(interface_name, interface_major)
  end

  defp handle_legacy_endpoint(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :endpoint) do
      changeset
    else
      path = get_change(changeset, :path)
      put_change(changeset, :endpoint, path)
    end
  end

  defp normalize_fields(changeset) do
    type_change = get_change(changeset, :type)

    changeset
    |> delete_change(:type)
    |> put_change(:value_type, type_change)
  end

  defp put_endpoint_id(changeset, interface_name, interface_major)
       when is_binary(interface_name) and is_integer(interface_major) do
    if endpoint_name = get_field(changeset, :endpoint) do
      endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, endpoint_name)
      put_change(changeset, :endpoint_id, endpoint_id)
    else
      changeset
    end
  end

  # Interface errors will be handled by the parent changeset, just force it to invalid
  defp put_endpoint_id(changeset, _interface_name, _interface_major) do
    %{changeset | valid?: false}
  end

  def mapping_regex do
    ~r/^(\/(%{([a-zA-Z_]+[a-zA-Z0-9_]*)}|[a-zA-Z_]+[a-zA-Z0-9_]*)){1,64}$/
  end

  @doc """
  Removes all placeholders from an endpoint.
  """
  @spec normalize_endpoint(String.t()) :: String.t()
  def normalize_endpoint(endpoint) when is_binary(endpoint) do
    String.replace(endpoint, @placeholder_regex, "")
  end

  @doc """
  Check if token is a placeholder.
  """
  @spec is_placeholder?(String.t()) :: boolean()
  def is_placeholder?(token) when is_binary(token) do
    String.match?(token, @placeholder_regex)
  end

  @doc """
  Deserializes a `%Mapping{}` from `db_result`.
  `db_result` can be a keyword list or a map.

  Returns the `%Mapping{}` on success,
  raises on failure
  """
  def from_db_result!(db_result) when not is_map(db_result) do
    db_result
    |> Enum.into(%{})
    |> from_db_result!()
  end

  def from_db_result!(db_result) do
    %{
      endpoint: endpoint,
      value_type: value_type,
      reliability: reliability,
      retention: retention,
      expiry: expiry,
      database_retention_policy: database_retention_policy,
      database_retention_ttl: database_retention_ttl,
      allow_unset: allow_unset,
      explicit_timestamp: explicit_timestamp,
      endpoint_id: endpoint_id,
      interface_id: interface_id,
      required: required
    } = db_result

    database_retention_policy =
      database_retention_policy
      |> Kernel.||(:no_ttl)
      |> DatabaseRetentionPolicy.cast!()

    doc = Map.get(db_result, :doc)
    description = Map.get(db_result, :description)

    %Mapping{
      endpoint: endpoint,
      value_type: ValueType.cast!(value_type),
      reliability: Reliability.cast!(reliability),
      retention: Retention.cast!(retention),
      expiry: expiry,
      database_retention_policy: database_retention_policy,
      database_retention_ttl: database_retention_ttl,
      allow_unset: allow_unset,
      explicit_timestamp: explicit_timestamp,
      endpoint_id: endpoint_id,
      interface_id: interface_id,
      doc: doc,
      description: description,
      required: Kernel.||(required, false)
    }
  end

  defp validate_not_set_unless(changeset, field, param, values) do
    if Enum.member?(values, param) do
      changeset
    else
      validate_change(changeset, field, &validate_field_is_blank/2)
    end
  end

  defp validate_field_is_blank(_field, nil), do: []
  defp validate_field_is_blank(field, _value), do: [{field, "must be blank"}]

  defp validate_database_retention_policy_and_ttl(changeset) do
    case {get_field(changeset, :database_retention_policy),
          get_field(changeset, :database_retention_ttl)} do
      {:no_ttl, any} when not is_nil(any) ->
        add_error(
          changeset,
          :database_retention_policy,
          "must be use_ttl if database_retention_ttl is set"
        )

      {:use_ttl, nil} ->
        add_error(
          changeset,
          :database_retention_ttl,
          "must be set if database_retention_policy is use_ttl"
        )

      _ ->
        changeset
    end
  end

  defimpl Jason.Encoder, for: Mapping do
    def encode(%Mapping{} = mapping, options) do
      %Mapping{
        endpoint: endpoint,
        value_type: value_type,
        reliability: reliability,
        retention: retention,
        expiry: expiry,
        database_retention_policy: database_retention_policy,
        database_retention_ttl: database_retention_ttl,
        allow_unset: allow_unset,
        explicit_timestamp: explicit_timestamp,
        description: description,
        doc: doc,
        required: required
      } = mapping

      %{
        endpoint: endpoint,
        type: value_type
      }
      |> add_key_if_not_default(:reliability, reliability, :unreliable)
      |> add_key_if_not_default(:retention, retention, :discard)
      |> add_key_if_not_default(:expiry, expiry, 0)
      |> add_key_if_not_default(:database_retention_policy, database_retention_policy, :no_ttl)
      |> add_key_if_not_nil(:database_retention_ttl, database_retention_ttl)
      |> add_key_if_not_default(:allow_unset, allow_unset, false)
      |> add_key_if_not_default(:explicit_timestamp, explicit_timestamp, false)
      |> add_key_if_not_nil(:description, description)
      |> add_key_if_not_nil(:doc, doc)
      |> add_key_if_not_default(:required, required, false)
      |> Jason.Encoder.Map.encode(options)
    end

    defp add_key_if_not_default(encode_map, _key, default, default), do: encode_map

    defp add_key_if_not_default(encode_map, key, value, _default) do
      Map.put(encode_map, key, value)
    end

    defp add_key_if_not_nil(encode_map, _key, nil), do: encode_map

    defp add_key_if_not_nil(encode_map, key, value) do
      Map.put(encode_map, key, value)
    end
  end
end
