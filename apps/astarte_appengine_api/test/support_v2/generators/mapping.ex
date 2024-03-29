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

defmodule Astarte.Test.Generators.Mapping do
  use ExUnitProperties

  alias Astarte.Core.Mapping

  defp endpoint(%{aggregation: aggregation, prefix: prefix}) do
    generator =
      case aggregation do
        :individual -> repeatedly(fn -> "/individual_#{System.unique_integer([:positive])}" end)
        :object -> repeatedly(fn -> "/object_#{System.unique_integer([:positive])}" end)
      end

    gen all postfix <- generator do
      prefix <> postfix
    end
  end

  defp type() do
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

  def reliability(), do: member_of([:unreliable, :guaranteed, :unique])

  def explicit_timestamp(), do: boolean()

  def retention(), do: member_of([:discard, :volatile, :stored])

  def expiry(), do: one_of([constant(0), integer(1..10_000)])

  def database_retention_policy(), do: member_of([:no_ttl, :use_ttl])

  def database_retention_ttl(), do: integer(0..10_1000)

  def allow_unset(), do: boolean()

  defp description(), do: string(:ascii, min_length: 1, max_length: 1000)

  defp doc(), do: string(:ascii, min_length: 1, max_length: 100_000)

  defp required_fields(%{
         aggregation: aggregation,
         prefix: prefix,
         retention: retention,
         reliability: reliability,
         explicit_timestamp: explicit_timestamp,
         allow_unset: allow_unset,
         expiry: expiry
       }) do
    fixed_map(%{
      endpoint: endpoint(%{aggregation: aggregation, prefix: prefix}),
      type: type(),
      retention: constant(retention),
      reliability: constant(reliability),
      explicit_timestamp: constant(explicit_timestamp),
      allow_unset: constant(allow_unset),
      expiry: constant(expiry)
    })
  end

  defp optional_fields(_config) do
    optional_map(%{
      database_retention_policy: database_retention_policy(),
      database_retention_ttl: database_retention_ttl(),
      description: description(),
      doc: doc()
    })
  end

  def mapping(config) do
    gen all required <- required_fields(config),
            optional <- optional_fields(config) do
      struct(Mapping, Map.merge(required, optional))
    end
  end
end
