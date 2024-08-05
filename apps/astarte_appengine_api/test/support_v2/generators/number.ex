defmodule Astarte.Test.Generators.Number do
  use ExUnitProperties

  def random_numbers(max) do
    gen all first <- StreamData.integer(0..max),
            second <- StreamData.integer(0..max),
            third <- StreamData.integer(0..max) do
      {first, second, third}
    end
  end
end
