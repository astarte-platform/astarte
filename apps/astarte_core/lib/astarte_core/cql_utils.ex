#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.Core.CQLUtils do
  @moduledoc """
  This module contains a set of functions that should be used to map Astarte types and concepts to C*
  """

  @value_type_to_db_type %{
    double: "double",
    integer: "int",
    boolean: "boolean",
    longinteger: "bigint",
    string: "varchar",
    binaryblob: "blob",
    datetime: "timestamp",
    doublearray: "list<double>",
    integerarray: "list<int>",
    booleanarray: "list<boolean>",
    longintegerarray: "list<bigint>",
    stringarray: "list<varchar>",
    binaryblobarray: "list<blob>",
    datetimearray: "list<timestamp>"
  }

  @type_to_db_column_name Map.new(@value_type_to_db_type, fn {k, _v} ->
                            {k, "#{k}_value"}
                          end)

  @interface_descriptor_statement """
    SELECT name, major_version, minor_version, type, ownership, aggregation
    FROM interfaces
    WHERE name=:name AND major_version=:major_version
  """

  @doc """
  Returns a generated table name that might be used during table creation."
  """
  def interface_name_to_table_name(interface_name, major_version) do
    safe_interface_name =
      interface_name
      |> String.downcase()
      |> String.replace(".", "_")
      |> String.replace("-", "")

    long_table_name = "#{safe_interface_name}_v" <> Integer.to_string(major_version)
    long_name_len = String.length(long_table_name)

    if long_name_len >= 45 do
      <<prefix::binary-size(6), _discard::binary>> =
        :crypto.hash(:sha256, long_table_name)
        |> Base.encode64()
        |> String.replace("+", "_")
        |> String.replace("/", "_")

      {_, shorter_name} = String.split_at(long_table_name, long_name_len - 39)

      "a#{prefix}_#{shorter_name}"
    else
      long_table_name
    end
  end

  @doc """
  Returns the column name for a certain endpoint that will be used for object interface tables.
  """
  def endpoint_to_db_column_name(endpoint_name) when is_binary(endpoint_name) do
    long_column_name_suffix =
      endpoint_name
      |> String.split("/")
      |> List.last()
      |> String.downcase()

    long_name_len = String.length(long_column_name_suffix)

    if long_name_len >= 44 do
      <<prefix::binary-size(6), _discard::binary>> =
        :crypto.hash(:sha256, long_column_name_suffix)
        |> Base.encode64()
        |> String.replace(~r/[+\/]/, "_")

      {_, shorter_name} = String.split_at(long_column_name_suffix, long_name_len - 38)

      "v_#{prefix}_#{shorter_name}"
    else
      "v_#{long_column_name_suffix}"
    end
  end

  @doc """
  Returns true if a given CQL name can be safely used for a table or a column name
  """
  def is_valid_cql_name?(cql_name) when is_binary(cql_name) do
    String.match?(cql_name, ~r/^[a-zA-Z]+[a-zA-Z0-9_]*$/) and String.length(cql_name) <= 48
  end

  @doc """
  Returns the CQL query statement that should be used to retrieve interface descriptor from the database.
  """
  def interface_descriptor_statement do
    @interface_descriptor_statement
  end

  @doc """
  Returns a CQL type for a given mapping value type atom
  """
  def mapping_value_type_to_db_type(value_type) do
    case Map.fetch(@value_type_to_db_type, value_type) do
      {:ok, db_type} -> db_type
      :error -> raise %CaseClauseError{term: value_type}
    end
  end

  @doc """
  Returns table column name that stores a certain type.
  """
  def type_to_db_column_name(column_type) do
    case Map.fetch(@type_to_db_column_name, column_type) do
      {:ok, column_name} -> column_name
      :error -> raise %CaseClauseError{term: column_type}
    end
  end

  @doc """
  Returns interface UUID for a certain `interface_name` with a certain `interface_major`
  """
  def interface_id(interface_name, interface_major)
      when is_binary(interface_name) and is_integer(interface_major) do
    iid_string = "iid:#{interface_name}:#{Integer.to_string(interface_major)}"

    <<iid::binary-size(16), _discard::binary>> = :crypto.hash(:sha256, iid_string)

    iid
  end

  @doc """
  returns an endpoint UUID for a certain `endpoint` on a certain `interface_name` with a certain `interface_major`.
  """
  def endpoint_id(interface_name, interface_major, endpoint)
      when is_binary(interface_name) and is_integer(interface_major) and is_binary(endpoint) do
    stripped_endpoint =
      endpoint
      |> String.replace(~r/%{[a-zA-Z0-9]*}/, "")

    eid_string =
      "eid:#{interface_name}:#{Integer.to_string(interface_major)}:#{stripped_endpoint}:"

    <<eid::binary-size(16), _discard::binary>> = :crypto.hash(:sha256, eid_string)

    eid
  end

  @spec realm_name_to_keyspace_name(nonempty_binary(), binary()) :: nonempty_binary()
  def realm_name_to_keyspace_name(realm_name, astarte_instance_id \\ "")
      when is_binary(realm_name) do
    instance_and_realm = astarte_instance_id <> realm_name

    case String.length(instance_and_realm) do
      len when len >= 48 -> Base.url_encode64(instance_and_realm, padding: false)
      _ -> instance_and_realm
    end
    |> String.replace("-", "")
    |> String.replace("_", "")
    |> String.slice(0..47)
    |> String.downcase()
  end
end
