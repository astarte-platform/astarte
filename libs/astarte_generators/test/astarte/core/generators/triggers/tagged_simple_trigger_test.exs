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

defmodule Astarte.Core.Generators.Triggers.TaggedSimpleTriggerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.SimpleTriggerConfig
  import Astarte.Core.Generators.Triggers.TaggedSimpleTrigger

  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger

  describe "tagged simple trigger generator" do
    property "generates serializable protobufs that roundtrip through their configuration" do
      check all config <- simple_trigger_config(),
                tagged_simple_trigger <- tagged_simple_trigger(config: config) do
        encoded = TaggedSimpleTrigger.encode(tagged_simple_trigger)
        decoded = TaggedSimpleTrigger.decode(encoded)

        roundtrip =
          decoded
          |> SimpleTriggerConfig.from_tagged_simple_trigger()
          |> SimpleTriggerConfig.to_tagged_simple_trigger()

        assert decoded == tagged_simple_trigger and roundtrip == tagged_simple_trigger
      end
    end
  end
end
