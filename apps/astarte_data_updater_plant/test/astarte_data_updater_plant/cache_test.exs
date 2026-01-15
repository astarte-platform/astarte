#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdater.CacheTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Mimic

  alias Astarte.DataUpdaterPlant.DataUpdater.Cache

  setup :verify_on_exit!

  describe "put/4 and get/3" do
    property "stores and retrieves the value for any key and value" do
      check all(
              key <- term(),
              value <- term(),
              size <- positive_integer(),
              ttl <- one_of([nil, integer()])
            ) do
        cache = Cache.new(size)
        cache = Cache.put(cache, key, value, ttl)

        if is_integer(ttl) and ttl <= 0 do
          assert Cache.get(cache, key) == nil
        else
          assert Cache.get(cache, key) == value
        end
      end
    end

    test "overwrites an existing key with a new value" do
      cache = Cache.new(2)
      cache = Cache.put(cache, :foo, 1, nil)
      cache = Cache.put(cache, :foo, 2, nil)
      assert Cache.get(cache, :foo) == 2
    end

    test "evicts a random key when cache exceeds capacity" do
      cache = Cache.new(2)
      cache = Cache.put(cache, :a, 1, nil)
      cache = Cache.put(cache, :b, 2, nil)
      cache = Cache.put(cache, :c, 3, nil)
      assert {2, map} = cache
      assert map_size(map) == 2
    end

    test "stores value with TTL and expires after TTL" do
      now = System.system_time(:second)
      System |> expect(:system_time, fn :second -> now end)

      cache = Cache.new(1)
      cache = Cache.put(cache, :foo, :bar, 1)

      # Simulate time after TTL
      System |> expect(:system_time, fn :second -> now + 2 end)
      assert Cache.get(cache, :foo) == nil
    end

    test "returns nil for missing keys" do
      cache = Cache.new(1)
      assert Cache.get(cache, :foo) == nil
    end

    test "returns default value for missing key" do
      cache = Cache.new(1)
      assert Cache.get(cache, :missing, :default) == :default
    end

    test "expired key is not returned but remains in map" do
      now = System.system_time(:second)
      System |> expect(:system_time, fn :second -> now end)

      cache = Cache.new(1)
      cache = Cache.put(cache, :foo, :bar, 1)

      # Simulate time after TTL
      System |> expect(:system_time, fn :second -> now + 2 end)
      assert Cache.get(cache, :foo, :default) == :default
    end
  end

  describe "fetch/2" do
    property "stores and retrieves the value for any key and value" do
      check all(
              key <- term(),
              value <- term(),
              size <- positive_integer(),
              ttl <- one_of([nil, integer()])
            ) do
        cache = Cache.new(size)
        cache = Cache.put(cache, key, value, ttl)

        if is_integer(ttl) and ttl <= 0 do
          assert Cache.fetch(cache, key) == :error
        else
          assert Cache.fetch(cache, key) == {:ok, value}
        end
      end
    end

    test "returns value for present and non-expired key" do
      cache = Cache.new(1)
      cache = Cache.put(cache, :foo, :bar, nil)
      assert Cache.fetch(cache, :foo) == {:ok, :bar}
    end

    test "returns :error for missing key" do
      cache = Cache.new(1)
      assert Cache.fetch(cache, :missing) == :error
    end

    test "expired key is not returned but remains in map" do
      # Set up the initial time for put
      now = System.system_time(:second)
      System |> expect(:system_time, fn :second -> now end)

      cache = Cache.new(1)
      cache = Cache.put(cache, :foo, :bar, 1)

      # Move time forward to simulate expiration
      System |> expect(:system_time, fn :second -> now + 2 end)

      assert Cache.fetch(cache, :foo) == :error
    end
  end

  describe "has_key?/2" do
    property "returns true if key is present and not expired, false otherwise" do
      check all(
              key <- term(),
              value <- term(),
              size <- positive_integer(),
              ttl <- one_of([nil, integer()])
            ) do
        cache = Cache.new(size)
        cache = Cache.put(cache, key, value, ttl)

        result = Cache.has_key?(cache, key)

        cond do
          is_integer(ttl) and ttl <= 0 ->
            assert result == false

          true ->
            assert result == true
        end
      end
    end

    test "returns true for present and non-expired key with no TTL" do
      cache = Cache.new(1)
      cache = Cache.put(cache, :foo, :bar, nil)
      assert Cache.has_key?(cache, :foo) == true
    end

    test "returns true for present and non-expired key with positive TTL" do
      cache = Cache.new(1)
      cache = Cache.put(cache, :foo, :bar, 1)
      assert Cache.has_key?(cache, :foo) == true
    end

    test "returns false for present but expired key" do
      now = System.system_time(:second)
      System |> expect(:system_time, fn :second -> now end)

      cache = Cache.new(1)
      cache = Cache.put(cache, :foo, :bar, 1)

      # Simulate time after TTL
      System |> expect(:system_time, fn :second -> now + 2 end)
      assert Cache.has_key?(cache, :foo) == false
    end

    test "returns false for missing key" do
      cache = Cache.new(1)
      assert Cache.has_key?(cache, :missing) == false
    end
  end
end
