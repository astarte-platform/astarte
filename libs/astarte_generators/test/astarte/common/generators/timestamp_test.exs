#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

  import Astarte.Common.Generators.Timestamp

  @moduletag :common
  @moduletag :timestamp

  @doc false
  describe "timestamp generator" do
    property "valid generic timestamp" do
      check all timestamp <- timestamp() do
        assert {:ok, _} = DateTime.from_unix(timestamp)
      end
    end

    property "valid timestamp using min" do
      check all from_ts <-
                  timestamp() |> filter(&(&1 > timestamp_min_default())),
                to_ts <- timestamp(min: from_ts) do
        assert to_ts > from_ts
      end
    end

    property "valid timestamp using max" do
      check all to_ts <-
                  timestamp() |> filter(&(&1 < timestamp_max_default())),
                from_ts <- timestamp(max: to_ts) do
        assert to_ts > from_ts
      end
    end
  end
end
