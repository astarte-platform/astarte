defmodule Astarte.InterfaceValuesRetrievealGenerators do
  use Astarte.Generators.Utilities.ParamsGen

  @doc """
  Generate valid Astarte.AppEngine.API.Device.InterfaceValuesOptions.
  For the nature of 
  """
  def interface_values_options(params \\ [], interface \\ nil) do
    # TODO: generate valid since, since_after, to values
    params gen all since <- nil,
                   since_after <- nil,
                   to <- nil,
                   limit <- optional(integer(1..1000)),
                   downsample_key <- nil,
                   downsample_to <- downsample_to(interface, downsample_key),
                   retrieve_metadata <- optional(boolean()),
                   allow_bigintegers <- optional(boolean()),
                   allow_safe_bigintegers <- optional(boolean()),
                   explicit_timestamp <- optional(boolean()),
                   keep_milliseconds <- optional(boolean()),
                   format <- format(),
                   params: params do
      %{
        since: since,
        since_after: since_after,
        to: to,
        limit: limit,
        downsample_to: downsample_to,
        downsample_key: downsample_key,
        retrieve_metadata: retrieve_metadata,
        allow_bigintegers: allow_bigintegers,
        allow_safe_bigintegers: allow_safe_bigintegers,
        explicit_timestamp: explicit_timestamp,
        keep_milliseconds: keep_milliseconds,
        format: format
      }
    end
  end

  defp optional(gen), do: one_of([nil, gen])
  defp format, do: member_of(["structured", "table", "disjoint_tables"])
  defp downsample_to, do: optional(integer(3..100))
  defp downsample_to(nil = _interface, _), do: nil

  defp downsample_to(interface, _downsample_key) when interface.aggregation == :individual do
    if Astarte.Helpers.Device.downsampable?(interface), do: downsample_to()
  end

  defp downsample_to(interface, nil = _downsample_key) when interface.aggregation == :object,
    do: nil

  defp downsample_to(interface, _downsample_key) when interface.aggregation == :object,
    do: downsample_to()
end
