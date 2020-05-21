#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.DataAccess.DatabaseTest do
  use ExUnit.Case
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Config.XandraNodes
  alias Astarte.DataAccess.Config.CQExNodes
  alias Astarte.DataAccess.Config

  test "just connect to the database" do
    {status, _db_client} = Database.connect()

    assert status == :ok
  end

  test "connect to missing realm" do
    assert Database.connect(realm: "missing") == {:error, :database_connection_error}
  end

  test "casting of cassandra nodes into skogsra custom types" do
    assert XandraNodes.cast("") == :error
    assert CQExNodes.cast("") == :error

    assert XandraNodes.cast("asinglenode:8080") == {:ok, ["asinglenode:8080"]}
    assert CQExNodes.cast("asinglenode:8080") == {:ok, [{"asinglenode", 8080}]}

    {:ok, xandra_nodes_list} = XandraNodes.cast("host1:8080, host2:8081")
    {:ok, cqex_nodes_list} = CQExNodes.cast("host1:8080, host2:8081")

    assert length(xandra_nodes_list) == 2
    assert "host1:8080" in xandra_nodes_list
    assert "host2:8081" in xandra_nodes_list

    assert length(cqex_nodes_list) == 2
    assert {"host1", 8080} in cqex_nodes_list
    assert {"host2", 8081} in cqex_nodes_list

    {:ok, xandra_nodes_list} = XandraNodes.cast("host1:8080, host2")
    {:ok, cqex_nodes_list} = CQExNodes.cast("host1:8080, host2")

    assert length(xandra_nodes_list) == 2
    assert "host1:8080" in xandra_nodes_list
    assert "host2" in xandra_nodes_list

    assert length(cqex_nodes_list) == 2
    assert {"host1", 8080} in cqex_nodes_list
    assert {"host2", 9042} in cqex_nodes_list
  end

  def reload_vars do
    Config.reload_xandra_nodes()
    Config.reload_cqex_nodes()
    Config.reload_ssl_enabled()
    Config.reload_cassandra_username()
    Config.reload_cassandra_password()
    Config.reload_pool_size()
    Config.reload_autodiscovery_enabled()
  end

  describe "verify xandra_options" do
    test "when SSL is enabled" do
      Config.put_xandra_nodes("host:1010")
      Config.put_ssl_enabled(true)
      Config.put_cassandra_username("user")
      Config.put_cassandra_password("password")
      Config.put_pool_size(100)
      Config.put_autodiscovery_enabled(true)
      Config.put_ssl_ca_file("cacert.pem")

      xandra_options =
        Config.xandra_options!()
        |> Keyword.put(:name, :cluster_name)

      auth_options = {Xandra.Authenticator.Password, [username: "user", password: "password"]}

      transport_options = [
        cacertfile: "cacerts.pem",
        verify: :verify_peer,
        server_name_indication: :disable
      ]

      assert length(xandra_options) == 7
      assert nodes: "host:1010" in xandra_options
      assert authentication: auth_options in xandra_options
      assert transport_options: transport_options in xandra_options
      assert name: :cluster_name in xandra_options
      assert autodiscovery: true in xandra_options
      assert pool_size: 100 in xandra_options
      assert encryption: true in xandra_options

      reload_vars()
    end

    test "when SSL is disabled" do
      Config.put_xandra_nodes("host:1010")
      Config.put_ssl_enabled(false)
      Config.put_cassandra_username("user")
      Config.put_cassandra_password("password")
      Config.put_pool_size(100)
      Config.put_autodiscovery_enabled(true)

      xandra_options =
        Config.xandra_options!()
        |> Keyword.put(:name, :cluster_name)

      auth_options = {Xandra.Authenticator.Password, [username: "user", password: "password"]}

      assert length(xandra_options) == 6
      assert nodes: "host:1010" in xandra_options
      assert authentication: auth_options in xandra_options
      assert name: :cluster_name in xandra_options
      assert autodiscovery: true in xandra_options
      assert pool_size: 100 in xandra_options
      assert encryption: true in xandra_options

      reload_vars()
    end
  end

  describe "verify cqex_options" do
    test "when SSL is enabled" do
      Config.put_cqex_nodes("host:1010")
      Config.put_ssl_enabled(true)
      Config.put_cassandra_username("user")
      Config.put_cassandra_password("password")
      Config.put_ssl_ca_file("cacert.pem")

      cqex_options =
        Config.cqex_options!()
        |> Keyword.put(:keyspace, :keyspace_name)

      ssl_options = [
        cacertfile: "cacert.pem",
        verify: :verify_peer,
        server_name_indication: :disable
      ]

      auth_options = {:cqerl_auth_plain_handler, [{"user", "password"}]}

      assert length(cqex_options) == 3
      assert keyspace: :keyspace_name in cqex_options
      assert ssl: ssl_options in cqex_options
      assert auth: auth_options in cqex_options

      reload_vars()
    end

    test "when SSL is disabled" do
      Config.put_cqex_nodes("host:1010")
      Config.put_ssl_enabled(false)
      Config.put_cassandra_username("user")
      Config.put_cassandra_password("password")
      Config.put_ssl_ca_file("cacert.pem")

      cqex_options =
        Config.cqex_options!()
        |> Keyword.put(:keyspace, :keyspace_name)

      auth_options = {:cqerl_auth_plain_handler, [{"user", "password"}]}

      assert length(cqex_options) == 2
      assert keyspace: :keyspace_name in cqex_options
      assert auth: auth_options in cqex_options

      reload_vars()
    end
  end
end
