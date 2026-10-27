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

defmodule Astarte.VMQ.Plugin.UtilsTest do
  use ExUnit.Case, async: true

  alias Astarte.VMQ.Plugin.Utils

  test "Returns functions with the same format as :vmq_reg.direct_plugin_exports" do
    assert {fun_0, fun_3, {nil, nil}} = Utils.empty_plugin_functions()

    assert is_function(fun_0, 0)
    assert is_function(fun_3, 3)
  end
end
