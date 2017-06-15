defmodule HousekeepingQueriesTest do
  use ExUnit.Case
  doctest HousekeepingEngine

  test "keyspace creation" do
    client = Housekeeping.Queries.connect
    assert(Housekeeping.Queries.create_astarte_keyspace(client) == :ok)
  end

  test "realm creation" do
    client = Housekeeping.Queries.connect
    assert(Housekeeping.Queries.create_realm(client, "test") == :ok)
  end
end
