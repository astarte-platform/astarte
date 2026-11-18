defmodule Astarte.HousekeepingWeb.GraphQL.SchemaTest do
  use Astarte.HousekeepingWeb.ConnCase, async: true
  use Astarte.HousekeepingWeb.AuthCase
  use Mimic

  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Realms

  @query_realms """
  query ListRealms {
    realms
  }
  """

  @query_health """
  query HealthCheck {
    health
  }
  """

  @query_default_replication """
  query DefaultReplication {
    defaultReplication
  }
  """

  describe "GraphQL queries" do
    setup do
      Mimic.stub(Astarte.Auth.OpenFGA, :check, fn _, _, _, _ -> :ok end)
      :ok
    end

    test "health query returns ok", %{auth_conn: conn} do
      conn =
        post(conn, "/v1/graphql", %{
          "query" => @query_health
        })

      assert json_response(conn, 200) == %{
               "data" => %{"health" => "ok"}
             }
    end

    test "realms query lists realms", %{auth_conn: conn} do
      Mimic.expect(Realms, :list_realms, fn -> {:ok, ["testrealm1", "testrealm2"]} end)

      conn =
        post(conn, "/v1/graphql", %{
          "query" => @query_realms
        })

      assert json_response(conn, 200) == %{
               "data" => %{"realms" => ["testrealm1", "testrealm2"]}
             }
    end

    test "defaultReplication query returns replication settings", %{auth_conn: conn} do
      Mimic.expect(Config, :astarte_keyspace_replication_strategy!, fn -> :simple_strategy end)
      Mimic.expect(Config, :astarte_keyspace_replication_factor!, fn -> 3 end)

      conn =
        post(conn, "/v1/graphql", %{
          "query" => @query_default_replication
        })

      assert json_response(conn, 200) == %{
               "data" => %{
                 "defaultReplication" => %{
                   "replication_class" => "simple_strategy",
                   "replication_factor" => 3
                 }
               }
             }
    end

    test "defaultReplication query maps network_topology_strategy", %{auth_conn: conn} do
      Mimic.expect(Config, :astarte_keyspace_replication_strategy!, fn ->
        :network_topology_strategy
      end)

      Mimic.expect(Config, :astarte_keyspace_network_replication_map!, fn -> %{"dc1" => 3} end)

      conn =
        post(conn, "/v1/graphql", %{
          "query" => @query_default_replication
        })

      assert json_response(conn, 200) == %{
               "data" => %{
                 "defaultReplication" => %{
                   "replication_class" => "network_topology_strategy",
                   "datacenter_replication_factor" => %{"dc1" => 3}
                 }
               }
             }
    end
  end
end
