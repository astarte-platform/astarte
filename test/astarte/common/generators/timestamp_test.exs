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

defmodule Astarte.Common.Generators.TimestampTest do
  @moduledoc """
  Tests for the Timestamp generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator

  @moduletag :common
  @moduletag :timestamp

  @min_epoch 0
  @max_epoch 2_556_143_999

  @doc """
  Property test for the Timestamp generator. It checks that the generated timestamp is within the
  specified range. The default range is 0..2_556_143_999.
  """
  describe "timestamp generator" do
    property "valid generic timestamp" do
      check all(timestamp <- TimestampGenerator.timestamp()) do
        assert {:ok, _} = DateTime.from_unix(timestamp)
      end
    end

    property "valid timestamp using min" do
      check all(
              from_ts <- TimestampGenerator.timestamp() |> filter(&(&1 > @min_epoch)),
              to_ts <- TimestampGenerator.timestamp(min: from_ts)
            ) do
        assert to_ts > from_ts
      end
    end

    property "valid timestamp using max" do
      check all(
              to_ts <- TimestampGenerator.timestamp() |> filter(&(&1 < @max_epoch)),
              from_ts <- TimestampGenerator.timestamp(max: to_ts)
            ) do
        assert to_ts > from_ts
      end
    end
  end
end
