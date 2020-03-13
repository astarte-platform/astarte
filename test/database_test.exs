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
end
