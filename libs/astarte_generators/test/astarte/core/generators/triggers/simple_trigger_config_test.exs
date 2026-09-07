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

defmodule Astarte.Core.Generators.Triggers.SimpleTriggerConfigTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.SimpleTriggerConfig
  import Astarte.Core.Generators.Triggers.SimpleTriggerConfigTest.Support

  describe "simple trigger configuration generator" do
    property "generates valid generic and selected configurations" do
      check all generic <- simple_trigger_config(),
                data <- simple_trigger_config(type: "data_trigger"),
                device <- simple_trigger_config(type: "device_trigger") do
        assert valid_config?(generic) and valid_config?(data) and valid_config?(device)
      end
    end
  end
end
