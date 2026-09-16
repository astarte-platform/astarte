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

defmodule Astarte.TestSuite.Cases.Device do
  @moduledoc false

  alias Astarte.TestSuite.Helpers.Device, as: DeviceHelper

  use Astarte.TestSuite.Case,
    name: :device,
    params: [
      devices: [default: {DeviceHelper, :devices}, type: :graph, graph_of: :map],
      allow_missing_credentials: [default: false, type: :boolean]
    ]

  alias Astarte.TestSuite.Fixtures.Device, as: DeviceFixtures

  setup_all [
    {DeviceFixtures, :data}
  ]
end
