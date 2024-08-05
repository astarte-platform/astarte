defmodule Astarte.Test.Generators.Mapping do
  use ExUnitProperties

  alias Astarte.Core.Mapping

  defp endpoint(%{aggregation: aggregation, prefix: prefix}) do
    # TODO: thinking about it
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
