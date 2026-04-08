defmodule Astarte.DataAccess.RepoTest do
  use ExUnit.Case

  alias Astarte.DataAccess.DatabaseTestHelper

  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  import Ecto.Query
  use Mimic

  setup_all do
    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
        DatabaseTestHelper.destroy_astarte_keyspace(conn)
      end)
    end)

    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
      DatabaseTestHelper.create_astarte_keyspace(conn)
    end)

    :ok
  end

  setup do
    realm = "testrealm#{System.unique_integer([:positive])}"

    {:ok, realm: realm}
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

    test "returns realm not found for queries on non-existing realms" do
      query = from k in "non_existing_realm.keyspaces", select: k.keyspace_name, limit: 1

      assert {:error, :realm_not_found} = Repo.safe_fetch_one(query)
    end

    test "returns error when the astarte keyspace does not exist" do
      Realm |> stub(:astarte_keyspace_name, fn -> "non_existing_realm" end)

      query = from k in "non_existing_realm.keyspaces", select: k.keyspace_name, limit: 1

      assert {:error, :database_error} = Repo.safe_fetch_one(query)
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
    test "realm returns ok", %{realm: realm} do
      assert {:ok, _} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: realm}],
                 prefix: "astarte"
               )
    end

    test "realm returns connection error", %{realm: realm} do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert {:error, :database_connection_error} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: realm}],
                 prefix: "astarte"
               )
    end

    test "realm returns db error", %{realm: realm} do
      Xandra
      |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: "generic error"}} end)

      assert {:error, :database_error} =
               Repo.safe_insert_all(
                 Realm,
                 [%{realm_name: realm}],
                 prefix: "astarte"
               )
    end
  end

  describe "safe_update_all" do
    test "realm returns ok", %{realm: realm} do
      old_realm_name = realm

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

    test "realm returns connection error", %{realm: realm} do
      old_realm_name = realm

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

    test "realm returns db error", %{realm: realm} do
      old_realm_name = realm

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
    test "realm returns ok", %{realm: realm} do
      old_realm_name = realm

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

    test "realm returns connection error", %{realm: realm} do
      old_realm_name = realm

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

    test "realm returns db error", %{realm: realm} do
      old_realm_name = realm

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

  describe "insert_to_sql from struct" do
    test "generates correct SQL and params", %{realm: realm} do
      struct = %Realm{realm_name: realm, device_registration_limit: nil}
      {sql, params} = Repo.insert_to_sql(struct, [])
      assert sql =~ "INSERT INTO realms"
      assert sql =~ "VALUES"
      assert is_list(params)
    end

    test "generates SQL with prefix from opts", %{realm: realm} do
      struct = %Realm{realm_name: realm, device_registration_limit: nil}
      {sql, _params} = Repo.insert_to_sql(struct, prefix: "astarte")
      assert sql =~ "astarte"
      assert sql =~ "realms"
    end
  end

  describe "insert_to_sql with table, value, opts" do
    test "generates basic INSERT SQL" do
      {sql, params} = Repo.insert_to_sql("mytable", %{col: "val"}, [])
      assert sql =~ "INSERT INTO mytable"
      assert sql =~ "VALUES"
      assert params == ["val"]
    end

    test "generates SQL without IF NOT EXISTS when overwrite is true (default)" do
      {sql, _params} = Repo.insert_to_sql("mytable", %{col: "val"}, overwrite: true)
      refute sql =~ "IF NOT EXISTS"
    end

    test "generates SQL with IF NOT EXISTS when overwrite is false" do
      {sql, _params} = Repo.insert_to_sql("mytable", %{col: "val"}, overwrite: false)
      assert sql =~ "IF NOT EXISTS"
    end

    test "generates SQL with USING TTL" do
      {sql, _params} = Repo.insert_to_sql("mytable", %{col: "val"}, ttl: 600)
      assert sql =~ "USING TTL 600"
    end

    test "generates SQL with AND TIMESTAMP" do
      {sql, _params} = Repo.insert_to_sql("mytable", %{col: "val"}, timestamp: 1_234_567_890)
      assert sql =~ "AND TIMESTAMP 1234567890"
    end

    test "generates SQL with both TTL and TIMESTAMP" do
      {sql, _params} =
        Repo.insert_to_sql("mytable", %{col: "val"}, ttl: 300, timestamp: 9_999_999)

      assert sql =~ "USING TTL 300"
      assert sql =~ "AND TIMESTAMP 9999999"
    end

    test "handles custom placeholder with list of values" do
      {sql, params} = Repo.insert_to_sql("mytable", %{col: {:custom, "now()", []}}, [])
      assert sql =~ "now()"
      assert params == []
    end

    test "handles custom placeholder with single value" do
      {sql, params} = Repo.insert_to_sql("mytable", %{col: {:custom, "?", :foo}}, [])
      assert sql =~ "?"
      assert params == [:foo]
    end

    test "handles custom placeholder with non-empty list of values" do
      {_sql, params} = Repo.insert_to_sql("mytable", %{col: {:custom, "?, ?", [1, 2]}}, [])
      assert params == [1, 2]
    end
  end

  describe "fetch" do
    setup context do
      realm_name = "fetch_test_#{System.unique_integer([:positive])}"

      {:ok, _} =
        Repo.safe_insert_all(
          Realm,
          [%{realm_name: realm_name}],
          prefix: "astarte"
        )

      Map.merge(context, %{realm_name: realm_name})
    end

    test "returns {:ok, record} when record exists", %{realm_name: realm_name} do
      query = from(r in Realm, prefix: "astarte")
      assert {:ok, %Realm{realm_name: ^realm_name}} = Repo.fetch(query, realm_name)
    end

    test "returns {:error, :not_found} when record does not exist" do
      query = from(r in Realm, prefix: "astarte")
      assert {:error, :not_found} = Repo.fetch(query, "non_existing_realm_xyz")
    end
  end

  describe "fetch_by" do
    setup context do
      realm_name = "fetch_by_test_#{System.unique_integer([:positive])}"

      {:ok, _} =
        Repo.safe_insert_all(
          Realm,
          [%{realm_name: realm_name}],
          prefix: "astarte"
        )

      Map.merge(context, %{realm_name: realm_name})
    end

    test "returns {:ok, record} when matching record exists", %{realm_name: realm_name} do
      assert {:ok, %Realm{realm_name: ^realm_name}} =
               Repo.fetch_by(from(r in Realm, prefix: "astarte"), realm_name: realm_name)
    end

    test "returns {:error, :not_found} when no matching record" do
      assert {:error, :not_found} =
               Repo.fetch_by(
                 from(r in Realm, prefix: "astarte"),
                 realm_name: "non_existing"
               )
    end

    test "returns custom error when option is provided" do
      assert {:error, :my_custom_error} =
               Repo.fetch_by(
                 from(r in Realm, prefix: "astarte"),
                 [realm_name: "non_existing"],
                 error: :my_custom_error
               )
    end
  end

  describe "safe_update" do
    setup context do
      realm_name = "update_test_#{System.unique_integer([:positive])}"

      {:ok, _} =
        Repo.safe_insert_all(
          Realm,
          [%{realm_name: realm_name}],
          prefix: "astarte"
        )

      {:ok, realm} = Repo.fetch(from(r in Realm, prefix: "astarte"), realm_name)
      Map.merge(context, %{realm: realm})
    end

    test "updates a record successfully", %{realm: realm} do
      changeset = Ecto.Changeset.change(realm, device_registration_limit: 99)
      assert {:ok, updated} = Repo.safe_update(changeset)
      assert updated.device_registration_limit == 99
    end

    test "returns database_connection_error on connection failure", %{realm: realm} do
      changeset = Ecto.Changeset.change(realm, device_registration_limit: 5)
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, :database_connection_error} = Repo.safe_update(changeset)
    end

    test "returns database_error on db failure", %{realm: realm} do
      changeset = Ecto.Changeset.change(realm, device_registration_limit: 5)

      Xandra
      |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: "generic error"}} end)

      assert {:error, :database_error} = Repo.safe_update(changeset)
    end
  end

  describe "some?" do
    test "returns {:ok, true} when a matching record exists", %{realm: realm} do
      {:ok, _} =
        Repo.safe_insert_all(
          Realm,
          [%{realm_name: realm}],
          prefix: "astarte"
        )

      query = from(r in Realm, prefix: "astarte", where: [realm_name: ^realm])

      assert {:ok, true} = Repo.some?(query)
    end

    test "returns {:ok, false} when no matching record exists" do
      query = from(r in Realm, prefix: "astarte", where: [realm_name: "non_existing_realm"])
      assert {:ok, false} = Repo.some?(query)
    end
  end
end
