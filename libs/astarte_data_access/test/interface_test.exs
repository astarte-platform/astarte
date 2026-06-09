#
# This file is part of Astarte.
#
# Copyright 2018 - 2026 SECO Mind Srl
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
  use Astarte.DataAccess.Cases.Database, async: true

  alias Astarte.Core.InterfaceDescriptor

  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Realms.Interface, as: InterfaceData

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

  describe "storage/1" do
    test "returns individual_properties if aggregation = individual and type = properties" do
      interface_chunk = %{aggregation: :individual, type: :properties}

      assert InterfaceData.storage(interface_chunk) == "individual_properties"
    end

    test "returns individual_datastream if aggregation = individual and type = datastream" do
      interface_chunk = %{aggregation: :individual, type: :datastream}

      assert InterfaceData.storage(interface_chunk) == "individual_datastreams"
    end

    test "returns interface_name_to_table_name if aggregation = object and type = datastream" do
      interface_chunk = %{
        aggregation: :object,
        type: :datastream,
        name: "com.test.SimpleStreamTest",
        major_version: 1
      }

      assert InterfaceData.storage(interface_chunk) == "com_test_simplestreamtest_v1"
    end
  end

  describe "storage_type/1" do
    test "returns multi_interface_individual_properties_dbtable if aggregation = individual and type = properties" do
      interface_chunk = %{aggregation: :individual, type: :properties}

      assert InterfaceData.storage_type(interface_chunk) ==
               :multi_interface_individual_properties_dbtable
    end

    test "returns multi_interface_individual_datastream_dbtable if aggregation = individual and type = datastream" do
      interface_chunk = %{aggregation: :individual, type: :datastream}

      assert InterfaceData.storage_type(interface_chunk) ==
               :multi_interface_individual_datastream_dbtable
    end

    test "returns one_object_datastream_dbtable if aggregation = object and type = datastream" do
      interface_chunk = %{aggregation: :object, type: :datastream}

      assert InterfaceData.storage_type(interface_chunk) ==
               :one_object_datastream_dbtable
    end
  end

  describe "check_if_interface_exists/3" do
    setup :seed_data

    test "returns expected values", %{realm_name: realm_name} do
      assert Interface.check_if_interface_exists(
               realm_name,
               "com.test.SimpleStreamTest",
               0
             ) ==
               {:error, :interface_not_found}

      assert Interface.check_if_interface_exists(
               realm_name,
               "com.test.SimpleStreamTest",
               1
             ) == :ok

      assert Interface.check_if_interface_exists(
               realm_name,
               "com.test.SimpleStreamTest",
               2
             ) ==
               {:error, :interface_not_found}

      assert Interface.check_if_interface_exists(realm_name, "com.Missing", 1) ==
               {:error, :interface_not_found}

      assert Interface.check_if_interface_exists(
               realm_name,
               "com.example.TestObject",
               0
             ) ==
               {:error, :interface_not_found}

      assert Interface.check_if_interface_exists(
               realm_name,
               "com.example.TestObject",
               1
             ) == :ok
    end
  end

  describe "fetch_interface_descriptor/3" do
    setup :seed_data

    test "returns an InterfaceDescriptor", %{realm_name: realm_name} do
      assert Interface.fetch_interface_descriptor(
               realm_name,
               "com.test.SimpleStreamTest",
               1
             ) ==
               {:ok, @simplestreamtest_interface_descriptor}
    end
  end

  describe "retrieve_interface_row/3" do
    setup :seed_data

    test "returns a row with expected values", %{realm_name: realm_name} do
      {:ok, row} = Interface.retrieve_interface_row(realm_name, "com.test.SimpleStreamTest", 1)

      assert is_map(row) == true

      assert Map.fetch(row, :name) == {:ok, "com.test.SimpleStreamTest"}
      assert Map.fetch(row, :interface_id) == {:ok, @simplestreamtest_interface_id}
      assert Map.fetch(row, :major_version) == {:ok, 1}
      assert Map.fetch(row, :minor_version) == {:ok, 0}
    end
  end
end
