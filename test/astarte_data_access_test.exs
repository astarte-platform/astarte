defmodule Astarte.DataAccessTest do
  use ExUnit.Case
  doctest Astarte.DataAccess

  test "greets the world" do
    assert Astarte.DataAccess.hello() == :world
  end
end
