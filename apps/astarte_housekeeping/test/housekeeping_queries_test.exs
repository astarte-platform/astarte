defmodule HousekeepingQueriesTest do
  use ExUnit.Case
  doctest HousekeepingEngine

  test "keyspace and realm creation" do
    client = Housekeeping.Queries.connect
    assert(Housekeeping.Queries.create_astarte_keyspace(client) == :ok)
    assert(Housekeeping.Queries.create_realm(client, "test") == :ok)
  end
end
