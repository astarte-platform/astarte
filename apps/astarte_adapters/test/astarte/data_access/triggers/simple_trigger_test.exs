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

defmodule Astarte.DataAccess.Adapters.Triggers.SimpleTriggerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Common.Generators.UUID
  import Astarte.Core.Generators.Triggers.AMQPTriggerTarget
  import Astarte.Core.Generators.Triggers.SimpleConfigs.SimpleTriggerConfig
  import Astarte.DataAccess.Adapters.Triggers.SimpleTrigger

  alias Astarte.Core.AstarteReference
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.SimpleTrigger

  describe "from core simple trigger to database changes" do
    property "maps a simple trigger and its lookup entry" do
      check all parent_trigger_id <- uuid(),
                simple_trigger_id <- uuid(),
                simple_trigger_config <- simple_trigger_config(),
                trigger_target <-
                  amqp_trigger_target(
                    parent_trigger_id: parent_trigger_id,
                    simple_trigger_id: simple_trigger_id
                  ) do
        source = %{
          simple_trigger_config: simple_trigger_config,
          trigger_target: trigger_target
        }

        %{
          simple_trigger:
            %{trigger_data: trigger_data, trigger_target: encoded_trigger_target} =
              simple_trigger,
          simple_trigger_reference: %{value: encoded_reference} = simple_trigger_reference
        } = from_core_simple_trigger_to_change(source)

        %{
          object_id: object_id,
          object_type: object_type,
          simple_trigger_container: simple_trigger_container
        } = SimpleTriggerConfig.to_tagged_simple_trigger(simple_trigger_config)

        expected_trigger_target = %TriggerTargetContainer{
          trigger_target: {:amqp_trigger_target, trigger_target}
        }

        expected_reference = %AstarteReference{
          object_type: object_type,
          object_uuid: object_id
        }

        assert %SimpleTrigger{} = struct(SimpleTrigger, simple_trigger)

        assert %KvStore{} =
                 struct(KvStore, Map.take(simple_trigger_reference, [:group, :key, :value]))

        assert simple_trigger == %{
                 object_id: object_id,
                 object_type: object_type,
                 parent_trigger_id: parent_trigger_id,
                 simple_trigger_id: simple_trigger_id,
                 trigger_data: SimpleTriggerContainer.encode(simple_trigger_container),
                 trigger_target: TriggerTargetContainer.encode(expected_trigger_target)
               }

        assert simple_trigger_reference == %{
                 group: "simple-triggers-by-uuid",
                 key: UUID.binary_to_string!(simple_trigger_id),
                 value: AstarteReference.encode(expected_reference)
               }

        assert SimpleTriggerContainer.decode(trigger_data) == simple_trigger_container
        assert TriggerTargetContainer.decode(encoded_trigger_target) == expected_trigger_target

        assert %TriggerTargetContainer{
                 trigger_target:
                   {:amqp_trigger_target,
                    %AMQPTriggerTarget{
                      parent_trigger_id: ^parent_trigger_id,
                      simple_trigger_id: ^simple_trigger_id
                    }}
               } = TriggerTargetContainer.decode(encoded_trigger_target)

        assert AstarteReference.decode(encoded_reference) == expected_reference
      end
    end
  end
end
