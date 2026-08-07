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

defmodule Astarte.TestSuite.Cases.Conn do
  @moduledoc false

  use Astarte.TestSuite.Case,
    name: :conn,
    params: [
      transport: [default: :mqtt, one_of: [:mqtt, :http]],
      port: [default: 1883, type: :positive_integer]
    ]

  alias Astarte.TestSuite.Fixtures.Conn, as: ConnFixtures

  setup_all [
    {ConnFixtures, :setup},
    {ConnFixtures, :data}
  ]
end
