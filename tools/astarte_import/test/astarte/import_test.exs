defmodule Astarte.ImportTest do
  use ExUnit.Case
  doctest Astarte.Import

  test "greets the world" do
    assert Astarte.Import.hello() == :world
  end
end
