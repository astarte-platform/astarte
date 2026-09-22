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

defmodule Astarte.DataAccess.Adapters.Triggers.SimpleTrigger do
  @moduledoc """
  Mappings from simple trigger configurations to their database entries.
  """
  use Astarte.Adapters

  alias Astarte.Core.AstarteReference
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.DataAccess.UUID, as: DataAccessUUID

  @type source :: %{
          parent_trigger_id: DataAccessUUID.t(),
          simple_trigger_config: SimpleTriggerConfig.t(),
          simple_trigger_id: DataAccessUUID.t(),
          trigger_target: AMQPTriggerTarget.t()
        }

  @type changes :: %{
          simple_trigger: map(),
          simple_trigger_reference: map()
        }

  transform from_core_simple_trigger_to_change do
    @source source()
    @returns changes()

    pre_process &pre_process/1

    keep :simple_trigger, :simple_trigger_reference
  end

  defp pre_process(%{
         parent_trigger_id: parent_trigger_id,
         simple_trigger_config: simple_trigger_config,
         simple_trigger_id: simple_trigger_id,
         trigger_target: %AMQPTriggerTarget{} = trigger_target
       }) do
    %TaggedSimpleTrigger{
      object_id: object_id,
      object_type: object_type,
      simple_trigger_container: simple_trigger_container
    } = SimpleTriggerConfig.to_tagged_simple_trigger(simple_trigger_config)

    trigger_target_container = %TriggerTargetContainer{
      trigger_target: {:amqp_trigger_target, trigger_target}
    }

    simple_trigger_reference = %AstarteReference{
      object_type: object_type,
      object_uuid: object_id
    }

    %{
      simple_trigger: %{
        object_id: object_id,
        object_type: object_type,
        parent_trigger_id: parent_trigger_id,
        simple_trigger_id: simple_trigger_id,
        trigger_data: SimpleTriggerContainer.encode(simple_trigger_container),
        trigger_target: TriggerTargetContainer.encode(trigger_target_container)
      },
      simple_trigger_reference: %{
        group: "simple-triggers-by-uuid",
        key: UUID.binary_to_string!(simple_trigger_id),
        value: AstarteReference.encode(simple_trigger_reference)
      }
    }
  end
end
