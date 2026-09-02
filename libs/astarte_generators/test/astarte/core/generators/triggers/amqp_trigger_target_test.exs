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

defmodule Astarte.Core.Generators.Triggers.AMQPTriggerTargetTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.AMQPTriggerTarget

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget

  describe "AMQP trigger target generator" do
    property "generates serializable targets with valid delivery fields" do
      check all target <- amqp_trigger_target() do
        %AMQPTriggerTarget{
          simple_trigger_id: simple_trigger_id,
          parent_trigger_id: parent_trigger_id,
          routing_key: routing_key,
          static_headers: static_headers,
          exchange: exchange,
          message_expiration_ms: message_expiration_ms,
          message_priority: message_priority,
          message_persistent: message_persistent
        } = target

        assert target == target |> AMQPTriggerTarget.encode() |> AMQPTriggerTarget.decode() and
                 byte_size(simple_trigger_id) == 16 and
                 byte_size(parent_trigger_id) == 16 and
                 byte_size(routing_key) in 1..64 and
                 map_size(static_headers) <= 8 and
                 (is_nil(exchange) or byte_size(exchange) in 1..64) and
                 message_expiration_ms in 1..2_147_483_647 and
                 message_priority in 0..9 and
                 is_boolean(message_persistent)
      end
    end
  end
end
