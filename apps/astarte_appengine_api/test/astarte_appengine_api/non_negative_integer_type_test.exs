# Copyright 2017-2020 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.AppEngine.API.NonNegativeIntegerTypeTest do
  use ExUnit.Case
  alias Astarte.AppEngine.API.Config.NonNegativeInteger

  test "Cast of NonNegativeInteger is valid" do
    assert NonNegativeInteger.cast("12") == {:ok, 12}
    assert NonNegativeInteger.cast("0") == {:ok, 0}
    assert NonNegativeInteger.cast("-10") == {:ok, 0}
    assert NonNegativeInteger.cast("") == :error
    assert NonNegativeInteger.cast("string") == :error
    assert NonNegativeInteger.cast([]) == :error
  end
end
