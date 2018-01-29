defmodule Astarte.Housekeeping.QueriesTest do
  use ExUnit.Case
  doctest Astarte.Housekeeping.Queries

  test "realm creation" do
    client = CQEx.Client.new!
    assert(Astarte.Housekeeping.Queries.create_realm(client, "test", "testpublickey") == :ok)
  end
end
