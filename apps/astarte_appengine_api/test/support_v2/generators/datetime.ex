defmodule Astarte.Test.Generators.DateTime do
  use ExUnitProperties

  @min_default 0
  @max_default 2_556_143_999

  def date_time!(opts \\ []) do
    opts = Keyword.validate!(opts, min: @min_default, max: @max_default)
    [min: min, max: max] = [min: Keyword.fetch!(opts, :min), max: Keyword.fetch!(opts, :max)]
    date_time!(min, max)
  end

  def invalid_datetime() do
    StreamData.one_of([
      StreamData.string(:printable, min_length: 1, max_length: 29),
      StreamData.string(:printable, min_length: 31, max_length: 50),
      StreamData.string(:printable, min_length: 1, max_length: 30)
      |> StreamData.filter(
        &(!String.match?(&1, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/))
      ),
      StreamData.binary(),
      StreamData.list_of(StreamData.integer(0..255), min_length: 1)
      |> StreamData.map(&Enum.join(&1))
    ])
  end

  def invalid_datetime_array() do
    StreamData.list_of(invalid_datetime(), min_length: 1, max_length: 10)
  end

  defp date_time!(min, max) when min < max, do: integer(min..max) |> map(&DateTime.from_unix!(&1))
  defp date_time!(min, max), do: raise("Datetime generator, received min: #{min} >= max: #{max}")
end
