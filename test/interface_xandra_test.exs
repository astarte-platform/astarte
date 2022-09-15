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

defmodule Astarte.DataAccess.Interfaces.XandraTest do
  use ExUnit.Case
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Config
  alias Astarte.DataAccess.Interface.Xandra, as: XandraInterface

  @simplestreamtest_interface_id <<10, 13, 167, 125, 133, 181, 147, 217, 212, 210, 189, 38, 221,
                                   24, 201, 175>>

  @simplestreamtest_interface_descriptor %InterfaceDescriptor{
    aggregation: :individual,
    automaton:
      {%{
         {0, ""} => 1,
         {0, "foo"} => 3,
         {1, "value"} => 2,
         {3, ""} => 4,
         {4, "blobValue"} => 6,
         {4, "longValue"} => 7,
         {4, "stringValue"} => 5,
         {4, "timestampValue"} => 8
       },
       %{
         2 => <<117, 1, 14, 27, 25, 158, 238, 252, 221, 53, 210, 84, 176, 226, 9, 36>>,
         5 => <<57, 7, 212, 29, 91, 202, 50, 157, 158, 81, 76, 234, 42, 84, 169, 154>>,
         6 => <<122, 164, 76, 17, 34, 115, 71, 217, 230, 36, 74, 224, 41, 222, 222, 170>>,
         7 => <<239, 249, 87, 207, 3, 223, 222, 237, 151, 132, 168, 112, 142, 61, 140, 185>>,
         8 => <<52, 108, 128, 228, 202, 153, 98, 116, 129, 246, 123, 28, 27, 229, 149, 33>>
       }},
    interface_id: @simplestreamtest_interface_id,
    major_version: 1,
    minor_version: 0,
    name: "com.test.SimpleStreamTest",
    ownership: :device,
    storage: "individual_datastreams",
    storage_type: :multi_interface_individual_datastream_dbtable,
    type: :datastream
  }

  @test_realm "autotestrealm"

  setup do
    DatabaseTestHelper.seed_data()
  end

  setup_all do
    {:ok, _client} = DatabaseTestHelper.create_test_keyspace()

    xandra_options =
      Config.xandra_options!()
      |> Keyword.put(:name, :xandra)

    Supervisor.start_link([{Xandra.Cluster, xandra_options}],
      strategy: :one_for_one,
      name: Astarte.DataAccess.Interface.XandraTest.Supervisor
    )

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  @tag :interesting
  test "check if interfaces exists" do
    Xandra.Cluster.run(:xandra, fn conn ->
      assert XandraInterface.check_if_interface_exists(
               conn,
               @test_realm,
               "com.test.SimpleStreamTest",
               0
             ) ==
               {:error, :interface_not_found}

      assert XandraInterface.check_if_interface_exists(
               conn,
               @test_realm,
               "com.test.SimpleStreamTest",
               1
             ) == :ok

      assert XandraInterface.check_if_interface_exists(
               conn,
               @test_realm,
               "com.test.SimpleStreamTest",
               2
             ) ==
               {:error, :interface_not_found}

      assert XandraInterface.check_if_interface_exists(conn, @test_realm, "com.Missing", 1) ==
               {:error, :interface_not_found}

      assert XandraInterface.check_if_interface_exists(
               conn,
               @test_realm,
               "com.example.TestObject",
               0
             ) ==
               {:error, :interface_not_found}

      assert XandraInterface.check_if_interface_exists(
               conn,
               @test_realm,
               "com.example.TestObject",
               1
             ) == :ok
    end)
  end

  @tag :interesting
  test "fetch_interface_descriptor returns an InterfaceDescriptor struct" do
    Xandra.Cluster.run(:xandra, fn conn ->
      assert XandraInterface.fetch_interface_descriptor(
               conn,
               @test_realm,
               "com.test.SimpleStreamTest",
               1
             ) ==
               {:ok, @simplestreamtest_interface_descriptor}
    end)
  end

  @tag :interesting
  test "retrieve_interface_row returns a row with expected values" do
    {:ok, row} =
      Xandra.Cluster.run(:xandra, fn conn ->
        XandraInterface.retrieve_interface_row(conn, @test_realm, "com.test.SimpleStreamTest", 1)
      end)

    assert is_map(row) == true

    assert %{
             "name" => "com.test.SimpleStreamTest",
             "interface_id" => @simplestreamtest_interface_id,
             "major_version" => 1,
             "minor_version" => 0
           } = row
  end
end
