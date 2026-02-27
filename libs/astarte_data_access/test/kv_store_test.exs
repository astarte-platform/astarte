#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.KvStoreTest do
  use ExUnit.Case
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.KvStore

  @test_realm "autotestrealm"
  @opts [prefix: @test_realm]

  setup_all do
    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
      end)
    end)

    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
    end)

    :ok
  end

  setup do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      Xandra.execute!(conn, "TRUNCATE #{@test_realm}.kv_store")
    end)

    :ok
  end

  describe "insert/2" do
    test "inserts a binary value" do
      assert :ok =
               KvStore.insert(
                 %{group: "test_group", key: "bin_key", value: <<1, 2, 3>>},
                 @opts
               )
    end

    test "inserts an integer value" do
      assert :ok =
               KvStore.insert(
                 %{group: "test_group", key: "int_key", value: 42, value_type: :integer},
                 @opts
               )
    end

    test "inserts a big integer value" do
      assert :ok =
               KvStore.insert(
                 %{
                   group: "test_group",
                   key: "bigint_key",
                   value: 9_999_999_999,
                   value_type: :big_integer
                 },
                 @opts
               )
    end

    test "inserts a string value" do
      assert :ok =
               KvStore.insert(
                 %{group: "test_group", key: "str_key", value: "hello", value_type: :string},
                 @opts
               )
    end

    test "inserts a uuid value" do
      assert :ok =
               KvStore.insert(
                 %{
                   group: "test_group",
                   key: "uuid_key",
                   value: Ecto.UUID.generate(),
                   value_type: :uuid
                 },
                 @opts
               )
    end

    test "defaults to binary value_type when not specified" do
      assert :ok =
               KvStore.insert(
                 %{group: "test_group", key: "default_key", value: <<0xFF>>},
                 @opts
               )
    end
  end

  describe "fetch_value/4" do
    test "fetches a binary value" do
      KvStore.insert(%{group: "g", key: "k", value: <<1, 2, 3>>}, @opts)

      assert {:ok, <<1, 2, 3>>} = KvStore.fetch_value("g", "k", :binary, @opts)
    end

    test "fetches an integer value" do
      KvStore.insert(%{group: "g", key: "int", value: 99, value_type: :integer}, @opts)

      assert {:ok, 99} = KvStore.fetch_value("g", "int", :integer, @opts)
    end

    test "fetches a big integer value" do
      KvStore.insert(
        %{group: "g", key: "bigint", value: 9_999_999_999, value_type: :big_integer},
        @opts
      )

      assert {:ok, 9_999_999_999} = KvStore.fetch_value("g", "bigint", :big_integer, @opts)
    end

    test "fetches a string value" do
      KvStore.insert(%{group: "g", key: "str", value: "world", value_type: :string}, @opts)

      assert {:ok, "world"} = KvStore.fetch_value("g", "str", :string, @opts)
    end

    test "fetches a uuid value" do
      expected_uuid = Ecto.UUID.generate()

      KvStore.insert(
        %{
          group: "test_group",
          key: "uuid_key",
          value: expected_uuid,
          value_type: :uuid
        },
        @opts
      )

      {:ok, uuid} = KvStore.fetch_value("test_group", "uuid_key", :uuid, @opts)

      assert {:ok, ^expected_uuid} = Ecto.UUID.cast(uuid)
    end

    test "returns error when key does not exist" do
      assert {:error, _} = KvStore.fetch_value("missing_group", "missing_key", :binary, @opts)
    end
  end
end
