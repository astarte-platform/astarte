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

defmodule Astarte.DataAccess.DateTimeTest do
  use ExUnit.Case, async: true
  alias Astarte.DataAccess.DateTime, as: AstarteDateTime

  @unix_timestamp 1_700_000_000
  @datetime DateTime.from_unix!(@unix_timestamp)

  describe "type/0" do
    test "returns :utc_datetime_msec" do
      assert AstarteDateTime.type() == :utc_datetime_msec
    end
  end

  describe "load/1" do
    test "loads a DateTime struct as-is" do
      assert AstarteDateTime.load(@datetime) == {:ok, @datetime}
    end

    test "loads a unix timestamp integer into a DateTime" do
      assert {:ok, %DateTime{} = dt} = AstarteDateTime.load(@unix_timestamp)
      assert DateTime.to_unix(dt) == @unix_timestamp
    end

    test "returns error for nil" do
      assert AstarteDateTime.load(nil) == :error
    end
  end

  describe "dump/1" do
    test "dumps a DateTime struct as-is" do
      assert AstarteDateTime.dump(@datetime) == {:ok, @datetime}
    end

    test "dumps an integer timestamp as-is" do
      assert AstarteDateTime.dump(@unix_timestamp) == {:ok, @unix_timestamp}
    end

    test "returns error for nil" do
      assert AstarteDateTime.dump(nil) == :error
    end
  end

  describe "cast/1" do
    test "casts a DateTime struct" do
      assert AstarteDateTime.cast(@datetime) == {:ok, @datetime}
    end

    test "casts an integer timestamp into a DateTime" do
      assert {:ok, %DateTime{}} = AstarteDateTime.cast(@unix_timestamp)
    end

    test "returns error for invalid input" do
      assert AstarteDateTime.cast("not a date") == :error
    end
  end

  describe "split_submillis/1" do
    test "truncates timestamp to millisecond precision" do
      dt = ~U[2023-11-14 22:13:20.123456Z]

      {ms_dt, _submillis} = AstarteDateTime.split_submillis(dt)

      assert ms_dt == ~U[2023-11-14 22:13:20.123Z]
    end
  end
end
