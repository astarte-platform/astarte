defmodule Astarte.PairingTest do
  use ExUnit.Case
  doctest Astarte.Pairing

  test "greets the world" do
    assert Astarte.Pairing.hello() == :world
  end
end
