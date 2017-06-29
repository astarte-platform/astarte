defmodule HousekeepingQueriesTest do
  use ExUnit.Case
  doctest Astarte.Housekeeping.Queries

  test "keyspace and realm creation" do
    client = Astarte.Housekeeping.Queries.connect
    assert(Astarte.Housekeeping.Queries.create_astarte_keyspace(client) == :ok)
    assert(Astarte.Housekeeping.Queries.create_realm(client, "test") == :ok)
  end
end
