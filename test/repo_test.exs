defmodule Astarte.DataAccess.RepoTest do
  use ExUnit.Case

  alias Astarte.DataAccess.DatabaseTestHelper

  alias Astarte.DataAccess.Repo

  import Ecto.Query
  use Mimic

  setup_all do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
    end)

    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
      end)
    end)

    :ok
  end

  describe "safe_fetch_one" do
    test "queries keyspaces returns ok" do
      query = from k in "system_schema.keyspaces", select: k.keyspace_name, limit: 1

      assert {:ok, _} = Repo.safe_fetch_one(query)
    end

    test "queries keyspaces connection error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      query = from k in "system_schema.keyspaces", select: k.keyspace_name, limit: 1

      assert {:error, :database_connection_error} = Repo.safe_fetch_one(query)
    end

    test "queries keyspaces without limit returns error" do
      query = from k in "system_schema.keyspaces", select: k.keyspace_name

      assert {:error, :multiple_results} = Repo.safe_fetch_one(query)
    end
  end
end
