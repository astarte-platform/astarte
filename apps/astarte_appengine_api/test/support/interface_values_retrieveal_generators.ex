defmodule Astarte.InterfaceValuesRetrievealGenerators do
  use Astarte.Generators.Utilities.ParamsGen

  @doc """
  Generate valid Astarte.AppEngine.API.Device.InterfaceValuesOptions.
  For the nature of 
  """
  def interface_values_options(params \\ []) do
    # TODO: generate valid since, since_after, to values
    params gen all limit <- optional(integer(0..1000)),
                   downsample_to <- optional(integer(0..1000)),
                   downsample_key <- nil,
                   retrieve_metadata <- optional(boolean()),
                   allow_bigintegers <- optional(boolean()),
                   allow_safe_bigintegers <- optional(boolean()),
                   explicit_timestamp <- optional(boolean()),
                   keep_milliseconds <- optional(boolean()),
                   format <- format(),
                   params: params do
      %{
        since: nil,
        since_after: nil,
        to: nil,
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
end
