defmodule Astarte.Test.Generators.Number do
  use ExUnitProperties

  def random_numbers(max) do
    gen all first <- StreamData.integer(0..max),
            second <- StreamData.integer(0..max),
            third <- StreamData.integer(0..max) do
      {first, second, third}
    end
  end

  def longinteger_array() do
    StreamData.one_of([
      StreamData.list_of(StreamData.integer(), min_length: 1, max_length: 10),
      StreamData.list_of(StreamData.map(StreamData.integer(), &Integer.to_string/1),
        min_length: 1,
        max_length: 10
      )
    ])
  end
end
