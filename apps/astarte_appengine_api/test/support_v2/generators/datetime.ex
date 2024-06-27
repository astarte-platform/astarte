defmodule Astarte.Test.Generators.DateTime do
  use ExUnitProperties

  @min_default 0
  @max_default 2_556_143_999

  def date_time!(opts \\ []) do
    [min: min, max: max] = Keyword.validate!(opts, min: @min_default, max: @max_default)
    date_time!(min, max)
  end

  defp date_time!(min, max) when min < max, do: integer(min..max) |> map(&DateTime.from_unix!(&1))
  defp date_time!(min, max), do: raise("Datetime generator, received min: #{min} >= max: #{max}")
end
