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
#

defmodule Astarte.Core.Generators.Mapping do
  @moduledoc """
  This module provides generators for Astarte Mapping structs.

  See https://docs.astarte-platform.org/astarte/latest/040-interface_schema.html#mapping
  """
  use Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Mapping

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  alias Astarte.Utilities.Map, as: MapUtilities

  @unix_prefix_path_chars [?a..?z, ?A..?Z, ?_]
  @unix_path_chars @unix_prefix_path_chars ++ [?0..?9]

  @doc """
  Generates a Mapping struct.
  See https://docs.astarte-platform.org/astarte/latest/040-interface_schema.html#mapping
  """
  @spec mapping() :: StreamData.t(Mapping.t())
  @spec mapping(params :: keyword()) :: StreamData.t(Mapping.t())
  def mapping(params \\ []) do
    params gen all interface_type <- InterfaceGenerator.type(),
                   interface_name <- InterfaceGenerator.name(),
                   interface_major <- InterfaceGenerator.major_version(),
                   endpoint <- endpoint(),
                   endpoint_id <- endpoint_id(interface_name, interface_major, endpoint),
                   type <- type(),
                   reliability <- reliability(interface_type),
                   explicit_timestamp <- explicit_timestamp(interface_type),
                   retention <- retention(interface_type),
                   expiry <- expiry(interface_type),
                   allow_unset <- allow_unset(interface_type),
                   database_retention_policy <- database_retention_policy(interface_type),
                   database_retention_ttl <-
                     database_retention_ttl(interface_type, database_retention_policy),
                   description <- description(),
                   doc <- doc(),
                   params: params do
      fields =
        MapUtilities.clean(%{
          endpoint: endpoint,
          endpoint_id: endpoint_id,
          type: type,
          value_type: type,
          reliability: reliability,
          explicit_timestamp: explicit_timestamp,
          retention: retention,
          expiry: expiry,
          database_retention_policy: database_retention_policy,
          allow_unset: allow_unset,
          database_retention_ttl: database_retention_ttl,
          description: description,
          doc: doc
        })

      struct(Mapping, fields)
    end
  end

  @doc """
  Convert this struct/stream to changes
  """
  @spec to_changes(Mapping.t()) :: StreamData.t(map())
  def to_changes(data) when not is_struct(data, StreamData),
    do: data |> constant() |> to_changes()

  @spec to_changes(StreamData.t(Mapping.t())) :: StreamData.t(map())
  def to_changes(gen) do
    gen all mapping <- gen do
      mapping
      |> Map.from_struct()
      |> Map.drop([:interface_id, :endpoint_id])
      |> MapUtilities.clean()
    end
  end

  @doc """
  Generates a mapping endpoint.
  """
  @spec endpoint() :: StreamData.t(String.t())
  def endpoint do
    gen all prefix <- endpoint_segment(),
            segments <-
              frequency([
                {3, endpoint_segment()},
                {1, endpoint_segment_param()}
              ])
              |> list_of(min_length: 1, max_length: 5) do
      "/" <> prefix <> "/" <> Enum.join(segments, "/")
    end
  end

  @doc """
  Generates a generic endpoint segment.
  """
  @spec endpoint_segment() :: StreamData.t(StreamData.t(String.t()))
  def endpoint_segment do
    gen all prefix <- string(@unix_prefix_path_chars, length: 1),
            rest <- string(@unix_path_chars, max_length: 19) do
      prefix <> rest
    end
  end

  @doc """
  Generates a parametrized endpoint segment.
  """
  @spec endpoint_segment_param() :: StreamData.t(StreamData.t(String.t()))
  def endpoint_segment_param,
    do: endpoint_segment() |> map(fn segment -> "%{" <> segment <> "}" end)

  defp endpoint_id(interface_name, interface_major, endpoint),
    do: constant(CQLUtils.endpoint_id(interface_name, interface_major, endpoint))

  defp type do
    member_of([
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
    ])
  end

  @doc false
  @spec reliability(:datastream | :properties) ::
          StreamData.t(:unreliable | :guaranteed | :unique)
  def reliability(:datastream), do: member_of([:unreliable, :guaranteed, :unique])
  def reliability(_), do: constant(nil)

  @doc false
  @spec explicit_timestamp(:datastream | :properties) :: StreamData.t(nil | boolean())
  def explicit_timestamp(:datastream), do: boolean()
  def explicit_timestamp(_), do: constant(false)

  @doc false
  @spec retention(:datastream | :properties) :: StreamData.t(:discard | :volatile | :stored)
  def retention(:datastream), do: member_of([:discard, :volatile, :stored])
  def retention(_), do: constant(:discard)

  @doc false
  @spec expiry(:datastream | :properties) :: StreamData.t(0 | pos_integer())
  def expiry(:datastream), do: one_of([constant(0), integer(1..10_000)])
  def expiry(_), do: constant(0)

  @doc false
  @spec database_retention_policy(:datastream | :properties) :: StreamData.t(:no_ttl | :use_ttl)
  def database_retention_policy(:datastream), do: member_of([:no_ttl, :use_ttl])
  def database_retention_policy(_), do: constant(nil)

  @doc false
  @spec database_retention_ttl(:datastream | :properties, :use_ttl | :no_ttl) ::
          StreamData.t(nil | non_neg_integer())
  def database_retention_ttl(:datastream, :use_ttl), do: integer(60..1_048_576)
  def database_retention_ttl(_, _), do: constant(nil)

  @doc false
  @spec allow_unset(:datastream | :properties) :: StreamData.t(boolean())
  def allow_unset(:properties), do: boolean()
  def allow_unset(_), do: constant(false)

  defp description, do: one_of([nil, string(:ascii, min_length: 1, max_length: 1000)])

  defp doc, do: one_of([nil, string(:ascii, min_length: 1, max_length: 100_000)])
end
