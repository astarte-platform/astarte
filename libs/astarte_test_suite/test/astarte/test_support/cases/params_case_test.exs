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

defmodule Astarte.TestSuiteTest.Cases.ParamsCaseTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuiteTest.Cases.ParamsCase

  test "validates keyword configuration" do
    assert ParamsCase.validate_config!(value: 1) == [value: 1]
  end

  test "rejects non keyword configuration" do
    assert_raise ArgumentError, ~r/expects a keyword list/, fn ->
      ParamsCase.validate_config!([:value])
    end
  end

  test "extracts default value" do
    assert ParamsCase.value!([]) == 0
  end

  test "extracts explicit value" do
    assert ParamsCase.value!(value: 5) == 5
  end

  test "rejects invalid values" do
    assert_raise ArgumentError, ~r/expects :value to be an integer/, fn ->
      ParamsCase.value!(value: "5")
    end
  end
end
