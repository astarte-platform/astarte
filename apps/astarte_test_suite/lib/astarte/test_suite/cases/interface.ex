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

defmodule Astarte.TestSuite.Cases.Interface do
  @moduledoc false

  alias Astarte.Core.Interface
  alias Astarte.TestSuite.Helpers.Interface, as: InterfaceHelper

  use Astarte.TestSuite.Case,
    name: :interface,
    params: [
      interface_number: [default: 3, type: :positive_integer],
      interfaces: [
        default: {InterfaceHelper, :interfaces},
        type: :graph,
        graph_of: Interface
      ]
    ]

  alias Astarte.TestSuite.Fixtures.Interface, as: InterfaceFixtures

  setup_all [
    {InterfaceFixtures, :data}
  ]
end
