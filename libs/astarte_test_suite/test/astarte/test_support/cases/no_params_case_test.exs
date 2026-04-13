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

defmodule Astarte.TestSuiteTest.Cases.NoParamsCaseTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuiteTest.Cases.NoParamsCase

  test "case template can be used without configuration" do
    module = Module.concat(__MODULE__, CompiledNoParamsCase)

    quoted =
      quote do
        defmodule unquote(module) do
          use ExUnit.Case
          use unquote(NoParamsCase)
        end
      end

    Code.compile_quoted(quoted)

    assert function_exported?(module, :__ex_unit__, 0)
  end
end
