defmodule Astarte.Test.Generators.Common do
  use ExUnitProperties

  def keyspace_name() do
    repeatedly(fn -> "realm#{System.unique_integer([:positive, :monotonic])}" end)
  end

  def ip() do
    gen all a <- integer(0..255),
            b <- integer(0..255),
            c <- integer(0..255),
            d <- integer(0..255) do
      {a, b, c, d}
    end
  end

  def invalid_binaryblob() do
    string(:printable, min_length: 1, max_length: 10)
    |> filter(&(!String.match?(&1, ~r/^[A-Za-z0-9\/\+\=]{0,2}$/)))
  end

  def invalid_binaryblob_array() do
    list_of(invalid_binaryblob(), min_length: 1, max_length: 10)
  end

  def object(expected_types) do
    fixed_map(
      Enum.into(expected_types, %{}, fn {key, type} ->
        {key, gen_value(type)}
      end)
    )
  end

  defp gen_value(:integer), do: integer()
  defp gen_value(:string), do: string(:printable)
  defp gen_value(:longinteger), do: integer()
end
