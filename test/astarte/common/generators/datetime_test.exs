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

defmodule Astarte.Common.Generators.DateTimeTest do
  @moduledoc """
  Tests for the DateTime generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Common.Generators.DateTime, as: DateTimeGenerator

  @moduletag :common
  @moduletag :datetime

  @doc false
  describe "DateTime generator" do
    property "valid generic DateTime with right precision" do
      check all date_time <- DateTimeGenerator.date_time() do
        assert %DateTime{microsecond: {_, 6}} = date_time
      end
    end

    property "valid DateTime using min" do
      check all from <-
                  DateTimeGenerator.date_time()
                  |> filter(&DateTime.after?(&1, DateTimeGenerator.min_default())),
                to <- DateTimeGenerator.date_time(min: from) do
        assert DateTime.after?(to, from)
      end
    end

    property "valid DateTime using max" do
      check all to <-
                  DateTimeGenerator.date_time()
                  |> filter(&DateTime.before?(&1, DateTimeGenerator.max_default())),
                from <- DateTimeGenerator.date_time(max: to) do
        assert DateTime.after?(to, from)
      end
    end
  end
end
