defmodule Astarte.DataAccess.RepoTest do
  use ExUnit.Case

  alias Astarte.DataAccess.DatabaseTestHelper

  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm

  import Ecto.Query
  use Mimic

  setup_all do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
      DatabaseTestHelper.create_astarte_keyspace(conn)
    end)

    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
        DatabaseTestHelper.destroy_astarte_keyspace(conn)
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

    test "queries keyspaces db error" do
      Xandra
      |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: "generic error"}} end)

      query = from k in "system_schema.keyspaces", select: k.keyspace_name, limit: 1

      assert {:error, :database_error} = Repo.safe_fetch_one(query)
    end

    test "queries keyspaces without limit returns error" do
      query = from k in "system_schema.keyspaces", select: k.keyspace_name

      assert {:error, :multiple_results} = Repo.safe_fetch_one(query)
    end
  end

  describe "fetch_all" do
    test "queries keyspaces returns ok" do
      query = from k in "system_schema.keyspaces", select: k.keyspace_name

      assert {:ok, _} = Repo.fetch_all(query)
    end

    test "queries keyspaces connection error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      query = from k in "system_schema.keyspaces", select: k.keyspace_name

      assert {:error, :database_connection_error} = Repo.fetch_all(query)
    end

    test "queries keyspaces db error" do
      Xandra
      |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: "generic error"}} end)

      query = from k in "system_schema.keyspaces", select: k.keyspace_name

      assert {:error, :database_error} = Repo.fetch_all(query)
    end
  end

  describe "safe_insert_all" do
    test "realm returns ok" do
      assert {:ok, _} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: "test#{System.unique_integer([:positive])}"}],
                 prefix: "astarte"
               )
    end

    test "realm returns connection error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert {:error, :database_connection_error} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: "test#{System.unique_integer([:positive])}"}],
                 prefix: "astarte"
               )
    end

    test "realm returns db error" do
      Xandra
      |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: "generic error"}} end)

      assert {:error, :database_error} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: "test#{System.unique_integer([:positive])}"}],
                 prefix: "astarte"
               )
    end
  end

  describe "safe_update_all" do
    test "realm returns ok" do
      old_realm_name = "test#{System.unique_integer([:positive])}"

      assert {:ok, _} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: old_realm_name}],
                 prefix: "astarte"
               )

      realm =
        from r in Realm,
          prefix: "astarte",
          where: [realm_name: ^old_realm_name],
          update: [set: [device_registration_limit: 10]]

      assert {:ok, _} = Repo.safe_update_all(realm, [])
    end

    test "realm returns connection error" do
      old_realm_name = "test#{System.unique_integer([:positive])}"

      assert {:ok, _} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: old_realm_name}],
                 prefix: "astarte"
               )

      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      realm =
        from r in Realm,
          prefix: "astarte",
          where: [realm_name: ^old_realm_name],
          update: [set: [device_registration_limit: 10]]

      assert {:error, :database_connection_error} = Repo.safe_update_all(realm, [])
    end

    test "realm returns db error" do
      old_realm_name = "test#{System.unique_integer([:positive])}"

      assert {:ok, _} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: old_realm_name}],
                 prefix: "astarte"
               )

      Xandra
      |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: "generic error"}} end)

      realm =
        from r in Realm,
          prefix: "astarte",
          where: [realm_name: ^old_realm_name],
          update: [set: [device_registration_limit: 10]]

      assert {:error, :database_error} = Repo.safe_update_all(realm, [])
    end
  end

  describe "safe_delete_all" do
    test "realm returns ok" do
      old_realm_name = "test#{System.unique_integer([:positive])}"

      assert {:ok, _} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: old_realm_name}],
                 prefix: "astarte"
               )

      realm =
        from r in Realm,
          prefix: "astarte",
          where: [realm_name: ^old_realm_name]

      assert {:ok, _} = Repo.safe_delete_all(realm, [])
    end

    test "realm returns connection error" do
      old_realm_name = "test#{System.unique_integer([:positive])}"

      assert {:ok, _} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: old_realm_name}],
                 prefix: "astarte"
               )

      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      realm =
        from r in Realm,
          prefix: "astarte",
          where: [realm_name: ^old_realm_name]

      assert {:error, :database_connection_error} = Repo.safe_delete_all(realm, [])
    end

    test "realm returns db error" do
      old_realm_name = "test#{System.unique_integer([:positive])}"

      assert {:ok, _} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: old_realm_name}],
                 prefix: "astarte"
               )

      Xandra
      |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: "generic error"}} end)

      realm =
        from r in Realm,
          prefix: "astarte",
          where: [realm_name: ^old_realm_name]

      assert {:error, :database_error} = Repo.safe_delete_all(realm, [])
    end
  end
end
