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

defmodule Astarte.DataAccess.NonNegativeIntegerOrUnsetTypeTest do
  use ExUnit.Case, async: true

  alias Astarte.DataAccess.NonNegativeIntegerOrUnsetType, as: Type

  describe "type/0" do
    test "returns :any" do
      assert Type.type() == :any
    end
  end

  describe "cast/1" do
    test "casts :unset" do
      assert Type.cast(:unset) == {:ok, :unset}
    end

    test "casts zero" do
      assert Type.cast(0) == {:ok, 0}
    end

    test "casts positive integer" do
      assert Type.cast(42) == {:ok, 42}
    end

    test "returns error for negative integer" do
      assert Type.cast(-1) == :error
    end

    test "returns error for not number value" do
      assert Type.cast("not number") == :error
    end
  end

  describe "load/1" do
    test "loads :unset" do
      assert Type.load(:unset) == {:ok, :unset}
    end

    test "loads integer" do
      assert Type.load(99) == {:ok, 99}
    end

    test "returns error for string" do
      assert Type.load("hello") == :error
    end
  end

  describe "dump/1" do
    test "dumps :unset" do
      assert Type.dump(:unset) == {:ok, :unset}
    end

    test "dumps integer" do
      assert Type.dump(7) == {:ok, 7}
    end

    test "returns error for string" do
      assert Type.dump("7") == :error
    end
  end
end
