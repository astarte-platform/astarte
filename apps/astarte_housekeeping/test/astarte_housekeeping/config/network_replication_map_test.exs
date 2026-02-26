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

defmodule Astarte.Housekeeping.Config.NetworkReplicationMapTest do
  use ExUnit.Case
  alias Astarte.Housekeeping.Config.NetworkReplicationMap

  describe "cast/1 casts" do
    test "a map of non-empty strings and positive integers" do
      assert {:ok, %{"dc1" => 1, "dc2" => 2}} =
               NetworkReplicationMap.cast(~s[{"dc1": 1, "dc2": 2}])
    end
  end

  describe "cast/1 does not cast" do
    test "negative integers as values" do
      assert :error = NetworkReplicationMap.cast("{\"datacenter1\": -1}")
    end

    test "empty keys" do
      assert :error = NetworkReplicationMap.cast("{\"\": 1}")
    end

    test "non-string keys" do
      assert :error = NetworkReplicationMap.cast("{2: 1}")
    end

    test "non-integer values" do
      assert :error = NetworkReplicationMap.cast(~S({"datacenter1": "invalid value"}))
    end

    test "non-objects as top-level elements" do
      assert :error = NetworkReplicationMap.cast(~S([{"datacenter1": ""}]))
    end

    test "empty value" do
      assert :error = NetworkReplicationMap.cast("")
    end

    test "nil" do
      assert :error = NetworkReplicationMap.cast(nil)
      assert :error = NetworkReplicationMap.cast("nil")
    end
  end
end
