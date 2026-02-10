#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.InterfaceUpdateGenerators do
  @moduledoc false
  # TODO: move all these generators to astarte_generators

  use ExUnitProperties
  import Astarte.Helpers.Device
  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator
  alias Astarte.Core.Mapping

  def valid_fallible_mapping_update_for(interface) when interface.aggregation == :individual,
    do: valid_mapping_update_for(interface)

  def valid_fallible_mapping_update_for(interface) when interface.aggregation == :object do
    endpoint = object_interface_endpoint(interface)
    value_types = object_interface_value_types(interface)
    reliability = object_interface_reliability(interface)

    fallible_value_types =
      value_types
      |> Enum.filter(fn {_key, value_type} -> value_type in fallible_value_types() end)
      |> Enum.map(fn {key, _value_type} -> key end)

    infallible_value_types =
      value_types
      |> Enum.reject(fn {key, _value_type} -> key in fallible_value_types end)

    infallible_value_types_gen =
      case infallible_value_types do
        [] -> constant([])
        types -> member_of(types) |> list_of()
      end

    gen all fallible_value_types <- fallible_value_types |> member_of() |> list_of(min_length: 1),
            other_value_types <- infallible_value_types_gen,
            types_to_keep = fallible_value_types ++ other_value_types,
            value_type <- fixed_map(value_types) |> map(&Map.take(&1, types_to_keep)),
            path <- path_from_endpoint(endpoint),
            value <- valid_update_value_for(value_type) do
      %{
        path: path,
        aggregation: :object,
        reliability: reliability,
        value: value,
        value_type: value_type
      }
    end
  end

  def valid_nonempty_mapping_update_for(interface) when interface.aggregation == :individual,
    do: valid_mapping_update_for(interface)

  def valid_nonempty_mapping_update_for(interface) when interface.aggregation == :object do
    endpoint = object_interface_endpoint(interface)
    value_types = object_interface_value_types(interface)
    reliability = object_interface_reliability(interface)

    value_type_keys = Map.keys(value_types)

    gen all value_type <- fixed_map(value_types),
            value_types_to_keep <- list_of(member_of(value_type_keys), min_length: 1),
            path <- path_from_endpoint(endpoint),
            value <- valid_update_value_for(value_type) do
      value_type = Map.take(value_type, value_types_to_keep)

      %{
        path: path,
        aggregation: :object,
        reliability: reliability,
        value: value,
        value_type: value_type
      }
    end
  end

  def valid_complete_mapping_update_for(interface) when interface.aggregation == :individual,
    do: valid_mapping_update_for(interface)

  def valid_complete_mapping_update_for(interface) when interface.aggregation == :object do
    endpoint = object_interface_endpoint(interface)
    value_types = object_interface_value_types(interface)
    reliability = object_interface_reliability(interface)

    gen all value_type <- fixed_map(value_types),
            path <- path_from_endpoint(endpoint),
            value <- valid_update_value_for(value_type) do
      %{
        path: path,
        aggregation: :object,
        reliability: reliability,
        value: value,
        value_type: value_type
      }
    end
  end

  def valid_mapping_update_for(interface) when interface.aggregation == :object do
    endpoint = object_interface_endpoint(interface)
    value_types = object_interface_value_types(interface)
    reliability = object_interface_reliability(interface)

    gen all value_type <- optional_map(value_types),
            path <- path_from_endpoint(endpoint),
            value <- valid_update_value_for(value_type) do
      %{
        path: path,
        aggregation: :object,
        reliability: reliability,
        value: value,
        value_type: value_type
      }
    end
  end

  def valid_mapping_update_for(interface) when interface.aggregation == :individual do
    reliability =
      case interface.type do
        :datastream -> fn mapping -> mapping.reliability end
        :properties -> fn _ -> :unique end
      end

    gen all mapping <- member_of(interface.mappings),
            path <- path_from_endpoint(mapping.endpoint),
            value <- valid_update_value_for(mapping.value_type) do
      %{
        path: path,
        aggregation: :individual,
        reliability: reliability.(mapping),
        value: value,
        value_type: mapping.value_type
      }
    end
  end

  def valid_update_value_for(value_types) when is_map(value_types) do
    value_types
    |> Map.new(fn {key, value_type} -> {key, random_value(value_type)} end)
    |> fixed_map()
  end

  def valid_update_value_for(value_type) when is_atom(value_type) do
    random_value(value_type)
  end

  def path_from_endpoint(prefix) do
    prefix
    |> String.split("/")
    |> Enum.map(fn token ->
      case Mapping.is_placeholder?(token) do
        true -> string(:alphanumeric, min_length: 1)
        false -> constant(token)
      end
    end)
    |> fixed_list()
    |> map(&Enum.join(&1, "/"))
  end

  defp too_large_array(inner_type), do: list_of(inner_type, min_length: 1025)

  def invalid_value(:integer), do: integer(0x7FFFFFFF..0xFFFFFFFF)
  def invalid_value(:longinteger), do: integer(0x7FFFFFFFFFFFFFFF..0xFFFFFFFFFFFFFFFF)

  def invalid_value(:string) do
    one_of([
      binary() |> filter(fn value -> not String.valid?(value) end),
      integer(65_537..120_000)
      |> map(&String.duplicate("a", &1))
    ])
  end

  def invalid_value(:binaryblob),
    do: integer(65_537..120_000) |> map(&String.duplicate("a", &1)) |> map(&Base.encode64/1)

  def invalid_value(:doublearray), do: too_large_array(float())

  def invalid_value(:integerarray),
    do: one_of([too_large_array(integer()), list_of(invalid_value(:integer), min_length: 1)])

  def invalid_value(:booleanarray), do: too_large_array(boolean())

  def invalid_value(:longintegerarray),
    do: one_of([too_large_array(integer()), list_of(invalid_value(:longinteger), min_length: 1)])

  def invalid_value(:stringarray),
    do:
      one_of([
        too_large_array(string(:alphanumeric)),
        list_of(invalid_value(:string), min_length: 1)
      ])

  def invalid_value(:binaryblobarray),
    do: one_of([too_large_array(binary()), list_of(invalid_value(:binaryblob), min_length: 1)])

  def invalid_value(:datetimearray), do: too_large_array(integer())

  def invalid_value(object_aggregate) when is_map(object_aggregate) do
    invalid_keys =
      object_aggregate
      |> Enum.filter(fn {_key, value_type} -> value_type in fallible_value_types() end)
      |> Enum.map(fn {key, _value_type} -> key end)

    gen all invalid_keys <- list_of(member_of(invalid_keys), min_length: 1),
            invalid_keys = Enum.uniq(invalid_keys),
            {invalid, other} = object_aggregate |> Map.split(invalid_keys),
            invalid <-
              invalid
              |> Map.new(fn {key, value_type} -> {key, invalid_value(value_type)} end)
              |> fixed_map(),
            other <-
              other
              |> Map.new(fn {key, value_type} -> {key, random_value(value_type)} end)
              |> fixed_map() do
      Map.merge(invalid, other)
    end
  end

  def invalid_type(value_types) when is_map(value_types) do
    one_of([invalid_map(value_types), random_except([])])
  end

  def invalid_type(type) when type in [:double, :integer, :longinteger], do: invalid_number()

  def invalid_type(:boolean), do: invalid_boolean()
  def invalid_type(:string), do: invalid_string()
  def invalid_type(:binaryblob), do: invalid_binary()
  def invalid_type(:datetime), do: invalid_datetime()

  def invalid_type(:doublearray), do: invalid_list_or(invalid_number())
  def invalid_type(:integerarray), do: invalid_list_or(invalid_number())
  def invalid_type(:longintegerarray), do: invalid_list_or(invalid_number())
  def invalid_type(:booleanarray), do: invalid_list_or(invalid_boolean())
  def invalid_type(:stringarray), do: invalid_list_or(invalid_string())
  def invalid_type(:binaryblobarray), do: invalid_list_or(invalid_binary())
  def invalid_type(:datetimearray), do: invalid_list_or(invalid_datetime())

  defp invalid_map(value_types) do
    invalid_key_subset =
      value_types
      |> Map.keys()
      |> member_of()
      |> list_of(min_length: 1)

    gen all invalid_keys <- invalid_key_subset,
            invalid_keys = Enum.dedup(invalid_keys),
            invalid_values <-
              value_types
              |> Map.take(invalid_keys)
              |> Map.new(fn {key, value_type} -> {key, invalid_type(value_type)} end)
              |> fixed_map(),
            valid_values <- valid_update_value_for(value_types) do
      Map.merge(valid_values, invalid_values)
    end
  end

  defp invalid_list_or(inner_type) do
    one_of([
      list_of(inner_type, min_length: 1),
      random_value(:double),
      random_value(:integer),
      random_value(:boolean),
      random_value(:longinteger),
      random_value(:string),
      random_value(:binaryblob),
      random_value(:datetime)
    ])
  end

  defp value_types do
    [
      :double,
      :integer,
      :boolean,
      :longinteger,
      :string,
      :binaryblob,
      :datetime,
      :doublearray,
      :integerarray,
      :booleanarray,
      :longintegerarray,
      :stringarray,
      :binaryblobarray,
      :datetimearray
    ]
  end

  defp invalid_number, do: random_except([:double, :integer, :longinteger, :datetime])
  defp invalid_boolean, do: random_except([:boolean])

  defp invalid_string do
    random_except([:string])
    |> filter(fn value ->
      not is_binary(value) or not String.valid?(value)
    end)
  end

  defp invalid_binary,
    do: random_except([:binaryblob]) |> filter(fn value -> not is_binary(value) end)

  defp invalid_datetime,
    do:
      random_except([:datetime, :double, :integer, :longinteger])
      |> filter(fn value ->
        not is_binary(value) or match?({:error, _}, DateTime.from_iso8601(value))
      end)

  defp random_except(invalid_types) do
    (value_types() -- invalid_types)
    |> Enum.map(&random_value/1)
    |> one_of()
  end

  defp random_value(:double), do: float()
  defp random_value(:boolean), do: boolean()
  defp random_value(:integer), do: gen_integer()
  defp random_value(:longinteger), do: gen_longinteger()
  defp random_value(:string), do: gen_string()
  defp random_value(:datetime), do: gen_datetime()
  defp random_value(:binaryblob), do: gen_binaryblob()

  defp random_value(:doublearray), do: list_of(float(), max_length: 1023)
  defp random_value(:booleanarray), do: list_of(boolean(), max_length: 1023)
  defp random_value(:integerarray), do: list_of(gen_integer(), max_length: 1023)
  defp random_value(:longintegerarray), do: list_of(gen_longinteger(), max_length: 1023)
  defp random_value(:stringarray), do: list_of(gen_string(), max_length: 1023)
  defp random_value(:datetimearray), do: list_of(gen_datetime(), max_length: 1023)
  defp random_value(:binaryblobarray), do: list_of(gen_binaryblob(), max_length: 1023)

  defp gen_integer, do: integer(-0x7FFFFFFF..0x7FFFFFFF)
  defp gen_longinteger, do: integer(-0x7FFFFFFFFFFFFFFF..0x7FFFFFFFFFFFFFFF)
  defp gen_string, do: string(:utf8, max_length: 65_535)

  defp gen_datetime do
    one_of([
      TimestampGenerator.timestamp(),
      TimestampGenerator.timestamp()
      |> map(&DateTime.from_unix!/1)
      |> map(&DateTime.to_iso8601/1)
    ])
  end

  defp gen_binaryblob, do: map(binary(max_length: 65_535), &Base.encode64/1)

  defp object_interface_value_types(interface) do
    # each interface must have at least 1 mapping
    first_mapping = interface.mappings |> Enum.at(0)
    prefix = String.replace(first_mapping.endpoint, ~r"/[^/]+$", "")
    prefix_with_slash = "#{prefix}/"

    interface.mappings
    |> Map.new(fn mapping ->
      key = String.replace_prefix(mapping.endpoint, prefix_with_slash, "")
      value_type = mapping.value_type

      {key, value_type}
    end)
  end

  defp object_interface_reliability(interface) when interface.type == :properties, do: :unique

  defp object_interface_reliability(interface) do
    # each interface must have at least 1 mapping
    first_mapping = interface.mappings |> Enum.at(0)
    first_mapping.reliability
  end

  defp object_interface_endpoint(interface) do
    # each interface must have at least 1 mapping
    first_mapping = interface.mappings |> Enum.at(0)
    String.replace(first_mapping.endpoint, ~r"/[^/]+$", "")
  end
end
