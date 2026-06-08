defmodule AstarteDevToolTest do
  use ExUnit.Case
  doctest AstarteDevTool

  test "greets the world" do
    assert AstarteDevTool.hello() == :world
  end
end
