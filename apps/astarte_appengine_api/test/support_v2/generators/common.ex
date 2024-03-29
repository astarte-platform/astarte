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
end
