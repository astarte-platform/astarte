#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.Test.Generators.Interface do
  use ExUnitProperties

  alias Ecto.UUID
  alias Astarte.Core.Interface
  alias Astarte.Test.Generators.String, as: StringGenerator
  alias Astarte.Test.Generators.Mapping, as: MappingGenerator

  defp id() do
    repeatedly(&UUID.generate/0)
  end

  defp name() do
    string(:alphanumeric, min_length: 1, max_length: 16)
    |> list_of(
      min_length: 2,
      max_length: 5
    )
    |> filter(fn [<<first, _::binary>> | _] ->
      first < 48 or first > 57
    end)
    |> map(&Enum.join(&1, "."))
  end

  defp versions() do
    gen all major_version <- integer(0..9),
            minor_version <- integer(0..255) do
      case {major_version, minor_version} do
        {0, 0} -> {0, 1}
        valid -> valid
      end
    end
  end

  defp type(), do: member_of([:datastream, :properties])

  defp ownership(), do: member_of([:device, :server])

  defp mappings(config) do
    uniq_list_of(MappingGenerator.mapping(config), min_length: 1, max_length: 1000)
  end

  defp aggregation(%{type: :properties}), do: constant(:individual)
  defp aggregation(_), do: member_of([:individual, :object])

  defp description() do
    string(:ascii, min_length: 1, max_length: 1000)
  end

  defp doc() do
    string(:ascii, min_length: 1, max_length: 100_000)
  end

  defp required_fields() do
    gen all id <- id(),
            name <- name(),
            {major_version, minor_version} <- versions(),
            type <- type(),
            aggregation <- aggregation(%{type: type}),
            ownership <- ownership(),
            prefix <- StringGenerator.endpoint_prefix(),
            retention <- MappingGenerator.retention(),
            reliability <- MappingGenerator.reliability(),
            expiry <- MappingGenerator.expiry(),
            allow_unset <- MappingGenerator.allow_unset(),
            explicit_timestamp <- MappingGenerator.explicit_timestamp(),
            mappings <-
              mappings(%{
                aggregation: aggregation,
                prefix: prefix,
                retention: retention,
                reliability: reliability,
                expiry: expiry,
                allow_unset: allow_unset,
                explicit_timestamp: explicit_timestamp
              }) do
      %{
        id: id,
        interface_id: id,
        name: name,
        interface_name: name,
        major_version: major_version,
        minor_version: minor_version,
        version_major: major_version,
        version_minor: minor_version,
        type: type,
        interface_type: type,
        ownership: ownership,
        aggregation: aggregation,
        mappings: mappings
      }
    end
  end

  defp optional_fields() do
    optional_map(%{
      description: description(),
      doc: doc()
    })
  end

  def interface() do
    gen all required <- required_fields(),
            optional <- optional_fields() do
      struct(Interface, Map.merge(required, optional))
    end
  end
end
