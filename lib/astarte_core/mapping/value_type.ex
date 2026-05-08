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

defmodule Astarte.Core.Mapping.ValueType do
  @moduledoc """
  Ecto type for Astarte mapping value types.
  """

  use Ecto.Type

  @type t ::
          :double
          | :integer
          | :boolean
          | :longinteger
          | :string
          | :binaryblob
          | :datetime
          | :doublearray
          | :integerarray
          | :booleanarray
          | :longintegerarray
          | :stringarray
          | :binaryblobarray
          | :datetimearray

  @mapping_value_type_double 1
  @mapping_value_type_doublearray 2
  @mapping_value_type_integer 3
  @mapping_value_type_integerarray 4
  @mapping_value_type_longinteger 5
  @mapping_value_type_longintegerarray 6
  @mapping_value_type_string 7
  @mapping_value_type_stringarray 8
  @mapping_value_type_boolean 9
  @mapping_value_type_booleanarray 10
  @mapping_value_type_binaryblob 11
  @mapping_value_type_binaryblobarray 12
  @mapping_value_type_datetime 13
  @mapping_value_type_datetimearray 14
  @valid_atoms [
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

  @atom_to_int %{
    double: @mapping_value_type_double,
    integer: @mapping_value_type_integer,
    boolean: @mapping_value_type_boolean,
    longinteger: @mapping_value_type_longinteger,
    string: @mapping_value_type_string,
    binaryblob: @mapping_value_type_binaryblob,
    datetime: @mapping_value_type_datetime,
    doublearray: @mapping_value_type_doublearray,
    integerarray: @mapping_value_type_integerarray,
    booleanarray: @mapping_value_type_booleanarray,
    longintegerarray: @mapping_value_type_longintegerarray,
    stringarray: @mapping_value_type_stringarray,
    binaryblobarray: @mapping_value_type_binaryblobarray,
    datetimearray: @mapping_value_type_datetimearray
  }

  @int_to_atom Map.new(@atom_to_int, fn {k, v} -> {v, k} end)

  @string_to_atom Map.new(@valid_atoms, fn atom -> {Atom.to_string(atom), atom} end)

  # The following limits are really conservative,
  # it is always easier to increase them in future releases
  @blob_size 65_536
  @list_len 1024
  @string_size 65_536

  @impl true
  def type, do: :integer

  @impl true
  def cast(nil), do: {:ok, nil}

  def cast(atom) when is_atom(atom) do
    if Enum.member?(@valid_atoms, atom) do
      {:ok, atom}
    else
      :error
    end
  end

  def cast(string) when is_binary(string) do
    Map.fetch(@string_to_atom, string)
  end

  def cast(int) when is_integer(int) do
    load(int)
  end

  def cast(_), do: :error

  def cast!(value) do
    case cast(value) do
      {:ok, value_type} ->
        value_type

      :error ->
        raise ArgumentError, message: "#{inspect(value)} is not a valid value type representation"
    end
  end

  @impl true
  def dump(value_type) when is_atom(value_type) do
    Map.fetch(@atom_to_int, value_type)
  end

  def dump!(value_type) when is_atom(value_type) do
    case dump(value_type) do
      {:ok, value_type_int} -> value_type_int
      :error -> raise ArgumentError, message: "#{inspect(value_type)} is not a valid value type"
    end
  end

  @impl true
  def load(value_type_int) when is_integer(value_type_int) do
    Map.fetch(@int_to_atom, value_type_int)
  end

  def to_int(value_type) when is_atom(value_type) do
    dump!(value_type)
  end

  def from_int(int) when is_integer(int) do
    cast!(int)
  end

  def validate_value(:double, v) when is_number(v), do: :ok
  def validate_value(:integer, v) when is_integer(v) and abs(v) <= 0x7FFFFFFF, do: :ok
  def validate_value(:boolean, v) when is_boolean(v), do: :ok
  def validate_value(:longinteger, v) when is_integer(v) and abs(v) <= 0x7FFFFFFFFFFFFFFF, do: :ok
  def validate_value(:string, v) when is_binary(v), do: validate_string_value(v)
  def validate_value(:binaryblob, v) when is_binary(v), do: validate_blob_size(v)

  def validate_value(:binaryblob, %Cyanide.Binary{data: bin}) when is_binary(bin),
    do: validate_blob_size(bin)

  def validate_value(:binaryblob, {_subtype, bin}) when is_binary(bin),
    do: validate_blob_size(bin)

  def validate_value(:datetime, %DateTime{}), do: :ok
  def validate_value(:datetime, v) when is_integer(v), do: :ok
  def validate_value(type, v) when is_list(v), do: validate_array_type(type, v)
  def validate_value(_type, _value), do: {:error, :unexpected_value_type}

  defp validate_string_value(v) do
    cond do
      not String.valid?(v) -> {:error, :unexpected_value_type}
      byte_size(v) > @string_size -> {:error, :value_size_exceeded}
      true -> :ok
    end
  end

  defp validate_blob_size(bin) do
    if byte_size(bin) > @blob_size do
      {:error, :value_size_exceeded}
    else
      :ok
    end
  end

  defp validate_array_type(:doublearray, v), do: validate_array_value(:double, v)
  defp validate_array_type(:integerarray, v), do: validate_array_value(:integer, v)
  defp validate_array_type(:booleanarray, v), do: validate_array_value(:boolean, v)
  defp validate_array_type(:longintegerarray, v), do: validate_array_value(:longinteger, v)
  defp validate_array_type(:stringarray, v), do: validate_array_value(:string, v)
  defp validate_array_type(:binaryblobarray, v), do: validate_array_value(:binaryblob, v)
  defp validate_array_type(:datetimearray, v), do: validate_array_value(:datetime, v)
  defp validate_array_type(_type, _v), do: {:error, :unexpected_value_type}

  defp validate_array_value(type, values) do
    cond do
      length(values) > @list_len ->
        {:error, :value_size_exceeded}

      Enum.all?(values, fn item -> validate_value(type, item) == :ok end) == false ->
        {:error, :unexpected_value_type}

      true ->
        :ok
    end
  end
end
