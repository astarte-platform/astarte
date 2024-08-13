#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.Test.Cases.Group do
  use ExUnit.CaseTemplate
  use Astarte.Test.Cases.Device
  alias Astarte.Test.Setups.Group, as: GroupSetup

  setup_all [
    {GroupSetup, :init},
    {GroupSetup, :setup}
  ]
end
