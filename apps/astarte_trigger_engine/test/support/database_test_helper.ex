defmodule Astarte.TriggerEngine.DatabaseTestHelper do
  # add a kv_store like this one:
  # "SELECT value FROM kv_store WHERE group='trigger_policy' AND key=:policy_name;"
  # where 'value' is a policy protobuf

  require Logger

  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.{KeywordError, RangeError, Handler}
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto

  @test_realm "autotestrealm"

  def create_db do
    create_autotestrealm_statement = """
    CREATE KEYSPACE autotestrealm
      WITH
      replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
      durable_writes = true;
    """

    create_kv_store_table_statement = """
    CREATE TABLE autotestrealm.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """

    with {:ok, _} <- Xandra.Cluster.execute(:xandra, create_autotestrealm_statement),
         {:ok, _} <- Xandra.Cluster.execute(:xandra, create_kv_store_table_statement) do
      :ok
    else
      {:error, error} ->
        Logger.error("Database initialization error: #{inspect(error)}", tag: :db_init_error)
        {:error, error}
    end
  end

  def populate_policies_db do
    {name1, policy1} =
      %Policy{
        name: "apolicy",
        maximum_capacity: 100,
        error_handlers: [
          %Handler{on: %KeywordError{keyword: "client_error"}, strategy: "retry"},
          %Handler{on: %RangeError{error_codes: [500, 501, 503]}, strategy: "discard"}
        ],
        retry_times: 10
      }
      |> Policy.to_policy_proto()
      |> PolicyProto.encode()
      |> (fn x -> {"apolicy", x} end).()

    {name2, policy2} =
      %Policy{
        name: "anotherpolicy",
        maximum_capacity: 100,
        error_handlers: [
          %Handler{on: %KeywordError{keyword: "any_error"}, strategy: "retry"}
        ],
        retry_times: 1
      }
      |> Policy.to_policy_proto()
      |> PolicyProto.encode()
      |> (fn x -> {"anotherpolicy", x} end).()

    insert_policy_statement =
      "INSERT INTO #{@test_realm}.kv_store (group, key, value) VALUES ('trigger_policy', :name, :proto)"

    with {:ok, prepared} <- Xandra.Cluster.prepare(:xandra, insert_policy_statement),
         {:ok, _res} <-
           Xandra.Cluster.execute(:xandra, prepared, %{"name" => name1, "proto" => policy1}),
         {:ok, _res} <-
           Xandra.Cluster.execute(:xandra, prepared, %{"name" => name2, "proto" => policy2}) do
      :ok
    end
  end

  def test_realm, do: @test_realm

  def drop_db do
    drop_statement = "DROP KEYSPACE #{@test_realm}"
    Xandra.Cluster.execute!(:xandra, drop_statement)
    :ok
  end
end
