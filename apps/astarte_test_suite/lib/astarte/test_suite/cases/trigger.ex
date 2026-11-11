#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.TestSuite.Cases.Trigger do
  @moduledoc false

  alias Astarte.Core.Triggers.Trigger
  alias Astarte.TestSuite.Helpers.Trigger, as: TriggerHelper

  use Astarte.TestSuite.Case,
    name: :trigger,
    params: [
      trigger_number: [default: 1, type: :positive_integer],
      triggers: [default: {TriggerHelper, :triggers}, type: :graph, graph_of: Trigger]
    ]

  alias Astarte.TestSuite.Fixtures.Trigger, as: TriggerFixtures

  setup_all [
    {TriggerFixtures, :data}
  ]
end
