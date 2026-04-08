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

%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["lib/", "test/", "config/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: [
        {Credo.Check.Readability.MaxLineLength, priority: :low, max_length: 100},
        {Credo.Check.Readability.Specs},
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Design.AliasUsage, priority: :low},
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 10},
        {Credo.Check.Refactor.FunctionArity, max_arity: 4},
        {Credo.Check.Refactor.Nesting, max_nesting: 3}
      ]
    }
  ]
}
