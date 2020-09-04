defmodule AstarteE2eTest do
  use ExUnit.Case
  doctest AstarteE2e

  test "greets the world" do
    assert AstarteE2e.hello() == :world
  end
end
