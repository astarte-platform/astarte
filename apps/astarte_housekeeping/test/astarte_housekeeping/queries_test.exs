defmodule Astarte.Housekeeping.V2.QueriesTest do
  use ExUnit.Case

  alias Astarte.Housekeeping.Helpers.Database
  # da verificare se serve ancora

  alias Astarte.Housekeeping.Queries

  use Mimic
  setup :set_mimic_private

  describe "database inizialization" do
    test "returns ok" do
      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
      end)

      assert :ok = Queries.initialize_database()
    end

    test "returns database error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)
      assert {:error, :database_error} = Queries.initialize_database()
    end

    test "returns connection error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, :database_connection_error} = Queries.initialize_database()
    end

    test "returns another error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, "generic error"} end)
      assert {:error, _} = Queries.initialize_database()
    end

    test "xandra throws an exception" do
      Xandra |> stub()
      assert_raise Mimic.UnexpectedCallError, fn -> Queries.initialize_database() end
    end
  end

  describe "create a realm," do
    setup do
      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
      end)

      Queries.initialize_database()
    end

    test "creations returns ok" do
      on_exit(fn ->
        Database.destroy_test_keyspace!(:xandra, "testrealm")
      end)

      assert :ok = Queries.create_realm("testrealm", "test1publickey", 1, 1, 1, [])
    end

    test "creations returns ok with nil replication factor" do
      on_exit(fn ->
        Database.destroy_test_keyspace!(:xandra, "testrealm")
      end)

      assert :ok = Queries.create_realm("testrealm", "test1publickey", nil, 1, 1, [])
    end

    test "creations returns ok with 0 max retentions factor" do
      on_exit(fn ->
        Database.destroy_test_keyspace!(:xandra, "testrealm")
      end)

      assert :ok = Queries.create_realm("testrealm", "test1publickey", 1, 1, 0, [])
    end

    test "creations returns error with bigger than nodes replication factor" do
      assert {:error,
              {:invalid_replication,
               "replication_factor 10 is >= 1 nodes in datacenter datacenter1"}} =
               Queries.create_realm("testrealm", "test1publickey", 10, 1, 1, [])
    end

    test "async creations returns ok" do
      on_exit(fn ->
        Process.sleep(1000)
        Database.destroy_test_keyspace!(:xandra, "testrealm")
      end)

      assert :ok = Queries.create_realm("testrealm", "test1publickey", 1, 1, 1, async: true)
    end

    test "creations returns an error" do
      Xandra.Cluster |> stub(:run, fn _, _, _ -> {:error, "generic error"} end)

      assert {:error, "generic error"} =
               Queries.create_realm("testrealm", "test1publickey", 1, 1, 1, [])
    end
  end

  describe "delete a realm," do
    setup do
      Database.setup!("testrealm")
    end

    test "deletions returns ok" do
      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
      end)

      assert :ok = Queries.delete_realm("testrealm", [])
    end

    test "async deletions returns ok" do
      on_exit(fn ->
        Process.sleep(1000)
        Database.destroy_test_astarte_keyspace!(:xandra)
      end)

      assert :ok = Queries.delete_realm("testrealm", async: true)
    end

    test "deletions returns an error" do
      on_exit(fn ->
        Database.teardown!("testrealm")
      end)

      Xandra.Cluster |> stub(:run, fn _, _, _ -> {:error, "generic error"} end)

      assert {:error, "generic error"} =
               Queries.delete_realm("testrealm")
    end
  end

  describe "list/get realm(s)," do
    setup do
      on_exit(fn ->
        Database.teardown!("testrealm")
      end)

      Database.setup!("testrealm")
      :ok
    end

    test "list returns one element" do
      assert {:ok, ["testrealm"]} = Queries.list_realms()
    end

    test "list returns two element" do
      on_exit(fn ->
        Queries.delete_realm("anotherrealm", [])
      end)

      assert :ok = Queries.create_realm("anotherrealm", "test2publickey", 1, 1, 1, [])

      assert {:ok, ["anotherrealm", "testrealm"]} = Queries.list_realms()
    end

    test "get returns the realm data just inserted" do
      on_exit(fn ->
        Queries.delete_realm("anotherrealm", [])
      end)

      assert :ok = Queries.create_realm("anotherrealm", "test2publickey", 1, 1, 1, [])

      assert %{
               replication_factor: 1,
               datastream_maximum_storage_retention: 1,
               device_registration_limit: 1,
               jwt_public_key_pem: "test2publickey",
               realm_name: "anotherrealm",
               replication_class: "SimpleStrategy"
             } = Queries.get_realm("anotherrealm")
    end

    test "get returns error due to get_public_key error" do
      on_exit(fn ->
        Queries.delete_realm("anotherrealm", [])
      end)

      assert :ok = Queries.create_realm("anotherrealm", "test2publickey", 1, 1, 1, [])
      Xandra |> stub(:execute, fn _, _, %{}, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert {:error, :database_connection_error} =
               Queries.get_realm("anotherrealm")
    end

    test "get returns the realm data just inserted, with a different replication class" do
      on_exit(fn ->
        Queries.delete_realm("anotherrealm", [])
      end)

      assert :ok =
               Queries.create_realm(
                 "anotherrealm",
                 "test2publickey",
                 %{"datacenter1" => 1},
                 1,
                 1,
                 []
               )

      assert %{
               datastream_maximum_storage_retention: 1,
               device_registration_limit: 1,
               jwt_public_key_pem: "test2publickey",
               realm_name: "anotherrealm",
               replication_class: "NetworkTopologyStrategy",
               datacenter_replication_factors: %{"datacenter1" => 1}
             } = Queries.get_realm("anotherrealm")
    end

    test "get returns error due to inconsistent db data" do
      # testrealm does not have a public key saved

      assert {:error, :public_key_not_found} = Queries.get_realm("testrealm")
    end

    test "get returns error due to not existent db data" do
      # testrealm does not have a public key saved

      assert {:error, :realm_not_found} = Queries.get_realm("fakerealm")
    end

    test "returns database error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)
      assert {:error, :database_error} = Queries.list_realms()
    end

    test "returns connection error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, :database_connection_error} = Queries.list_realms()
    end
  end

  describe "realm exists," do
    setup do
      on_exit(fn ->
        Database.teardown!("testrealm")
      end)

      Database.setup!("testrealm")
    end

    test "true" do
      assert {:ok, true} = Queries.is_realm_existing("testrealm")
    end

    test "error due to db connection" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, _} = Queries.is_realm_existing("testrealm")
    end

    test "false" do
      assert {:ok, false} = Queries.is_realm_existing("testrealm2")
    end
  end

  describe "astarte keyspace exists," do
    test "true" do
      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
      end)

      assert :ok = Queries.initialize_database()
      assert {:ok, true} = Queries.is_astarte_keyspace_existing()
    end

    test "false" do
      assert {:ok, false} = Queries.is_astarte_keyspace_existing()
    end

    test "fails due to db error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)
      assert {:error, :database_error} = Queries.is_astarte_keyspace_existing()
    end

    test "fails due to db connection error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert {:error, :database_connection_error} = Queries.is_astarte_keyspace_existing()
    end

    test "raise due to generic error" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, "another error"} end)

      assert_raise CaseClauseError, fn -> Queries.is_astarte_keyspace_existing() end
    end
  end
end
