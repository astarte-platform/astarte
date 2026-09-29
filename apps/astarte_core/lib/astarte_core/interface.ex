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

defmodule Astarte.Core.Interface do
  @moduledoc """
  Defines the schema and changeset for Astarte interfaces.
  """

  use TypedEctoSchema
  import Ecto.Changeset

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface
  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Ownership
  alias Astarte.Core.Interface.Type
  alias Astarte.Core.Mapping

  @required_fields [
    :interface_name,
    :version_major,
    :version_minor,
    :type,
    :ownership
  ]

  @permitted_fields [
    :aggregation,
    :quality,
    :aggregate,
    :description,
    :doc
    | @required_fields
  ]

  @primary_key false
  typed_embedded_schema do
    field :interface_id, :binary
    field :name
    field :major_version, :integer
    field :minor_version, :integer
    field :type, Type
    field :ownership, Ownership
    field :aggregation, Aggregation, default: :individual
    field :description
    field :doc
    embeds_many :mappings, Mapping
    # Legacy
    field :quality, Ownership, virtual: true
    field :aggregate, :boolean, virtual: true
    # Different input naming
    field :interface_name, :string, virtual: true
    field :version_major, :integer, virtual: true
    field :version_minor, :integer, virtual: true
  end

  def changeset(%Interface{} = interface, params \\ %{}) do
    changeset =
      interface
      |> cast(params, @permitted_fields)
      |> handle_legacy_ownership()
      |> handle_legacy_aggregation()
      |> validate_required(@required_fields)
      |> validate_length(:interface_name, max: 128)
      |> validate_format(:interface_name, interface_name_regex())
      |> validate_exclusion(:interface_name, ["astarte", "control", "device"])
      |> validate_number(:version_major, greater_than_or_equal_to: 0)
      |> validate_number(:version_minor, greater_than_or_equal_to: 0)
      |> validate_non_null_version()
      |> validate_length(:description, max: 1000)
      |> validate_length(:doc, max: 100_000)
      |> validate_interface_attributes_combinations()
      |> put_interface_id()
      |> normalize_fields()

    # We break the pipe because we need the changeset as argument to mapping_changeset
    changeset
    |> cast_embed(:mappings, required: true, with: mapping_changeset(changeset))
    |> validate_length(:mappings, min: 1, max: 1024)
    |> validate_mapping_uniqueness()
    |> validate_all_mappings_have_same_attributes()
    |> validate_all_mappings_have_same_prefix()
  end

  def interface_name_regex do
    ~r/^([a-zA-Z][a-zA-Z0-9]*\.([a-zA-Z0-9][a-zA-Z0-9-]*\.)*)?[a-zA-Z][a-zA-Z0-9]*$/
  end

  defp handle_legacy_ownership(changeset) do
    if get_field(changeset, :ownership) do
      delete_change(changeset, :quality)
    else
      quality = get_change(changeset, :quality)

      changeset
      |> delete_change(:quality)
      |> put_change(:ownership, quality)
    end
  end

  defp handle_legacy_aggregation(changeset) do
    cond do
      get_change(changeset, :aggregation) ->
        delete_change(changeset, :aggregate)

      get_field(changeset, :aggregate) ->
        changeset
        |> delete_change(:aggregate)
        |> put_change(:aggregation, :object)

      true ->
        changeset
    end
  end

  defp mapping_changeset(%Ecto.Changeset{} = changeset) do
    name = get_field(changeset, :name)
    major = get_field(changeset, :major_version)
    minor = get_field(changeset, :minor_version)
    interface_id = get_field(changeset, :interface_id)
    type = get_field(changeset, :type)
    aggregation = get_field(changeset, :aggregation)

    opts = [
      interface_name: name,
      interface_major: major,
      interface_minor: minor,
      interface_id: interface_id,
      interface_type: type,
      interface_aggregation: aggregation
    ]

    fn type, params ->
      Mapping.changeset(type, params, opts)
    end
  end

  # Map the input fields to the expected internal fields
  defp normalize_fields(changeset) do
    name = get_field(changeset, :interface_name)
    major = get_field(changeset, :version_major)
    minor = get_field(changeset, :version_minor)

    changeset
    |> delete_change(:interface_name)
    |> delete_change(:version_major)
    |> delete_change(:version_minor)
    |> put_change(:name, name)
    |> put_change(:major_version, major)
    |> put_change(:minor_version, minor)
  end

  defp put_interface_id(changeset) do
    with {_, name} when is_binary(name) <- fetch_field(changeset, :interface_name),
         {_, major} when is_integer(major) <- fetch_field(changeset, :version_major) do
      interface_id = CQLUtils.interface_id(name, major)

      changeset
      |> put_change(:interface_id, interface_id)
    else
      _ ->
        changeset
    end
  end

  defp validate_non_null_version(changeset) do
    if get_field(changeset, :version_major) == 0 and get_field(changeset, :version_minor) == 0 do
      add_error(changeset, :version_minor, "must be > 0 if major_version is 0")
    else
      changeset
    end
  end

  defp validate_interface_attributes_combinations(%Ecto.Changeset{valid?: true} = changeset) do
    interface_type = get_field(changeset, :type)
    aggregation = get_field(changeset, :aggregation, :individual)

    if interface_type == :properties and aggregation == :object do
      add_error(changeset, :aggregation, "must be individual for properties interfaces")
    else
      changeset
    end
  end

  defp validate_interface_attributes_combinations(%Ecto.Changeset{valid?: false} = changeset) do
    changeset
  end

  defp validate_mapping_uniqueness(%Ecto.Changeset{valid?: true} = changeset) do
    mappings = get_field(changeset, :mappings, [])

    unique_count =
      Enum.uniq_by(mappings, fn mapping ->
        Mapping.normalize_endpoint(mapping.endpoint)
        |> String.downcase()
      end)
      |> Enum.count()

    if Enum.count(mappings) != unique_count do
      add_error(changeset, :mappings, "contain conflicting endpoints")
    else
      changeset
    end
  end

  defp validate_mapping_uniqueness(%Ecto.Changeset{valid?: false} = changeset) do
    changeset
  end

  defp validate_all_mappings_have_same_attributes(changeset) do
    mappings = get_field(changeset, :mappings, [])
    aggregation = get_field(changeset, :aggregation, :individual)

    if aggregation == :object and mappings != [] do
      first = List.first(mappings)

      if Enum.all?(mappings, &same_object_attributes?(first, &1)) do
        changeset
      else
        add_error(changeset, :mappings, "contain conflicting attributes")
      end
    else
      changeset
    end
  end

  defp same_object_attributes?(%Mapping{} = a, %Mapping{} = b) do
    a.retention == b.retention and
      a.reliability == b.reliability and
      a.expiry == b.expiry and
      a.allow_unset == b.allow_unset and
      a.explicit_timestamp == b.explicit_timestamp and
      a.database_retention_policy == b.database_retention_policy and
      a.database_retention_ttl == b.database_retention_ttl
  end

  defp validate_all_mappings_have_same_prefix(changeset) do
    mappings = get_field(changeset, :mappings, [])
    aggregation = get_field(changeset, :aggregation, [])

    if aggregation == :object and mappings != [] do
      common_prefix =
        mappings
        |> List.first()
        |> Map.get(:endpoint)
        |> String.split("/")
        |> List.delete_at(-1)

      all_same_prefix =
        Enum.all?(mappings, fn mapping ->
          current_prefix =
            mapping
            |> Map.get(:endpoint)
            |> String.split("/")
            |> List.delete_at(-1)

          current_prefix == common_prefix
        end)

      if all_same_prefix do
        changeset
      else
        add_error(changeset, :mappings, "must have the same prefix in endpoints")
      end
    else
      changeset
    end
  end

  defimpl Jason.Encoder, for: Interface do
    def encode(%Interface{} = interface, options) do
      %Interface{
        name: name,
        major_version: major_version,
        minor_version: minor_version,
        type: type,
        ownership: ownership,
        aggregation: aggregation,
        description: description,
        doc: doc,
        mappings: mappings
      } = interface

      %{
        interface_name: name,
        version_major: major_version,
        version_minor: minor_version,
        type: type,
        ownership: ownership,
        mappings: mappings
      }
      |> add_key_if_not_default(:aggregation, aggregation, :individual)
      |> add_key_if_not_nil(:description, description)
      |> add_key_if_not_nil(:doc, doc)
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
