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
  Mappings from simple trigger configurations and targets to their database entries.
  """
  use Astarte.Adapters

  alias Astarte.Core.AstarteReference
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer

  @type source :: %{
          required(:simple_trigger_config) => SimpleTriggerConfig.t(),
          required(:trigger_target) => AMQPTriggerTarget.t()
        }

  @type changes :: %{
          simple_trigger: map(),
          simple_trigger_reference: map()
        }

  transform from_core_simple_trigger_to_change do
    @source source()
    @returns changes()

    field :simple_trigger, &simple_trigger_change/1
    field :simple_trigger_reference, &simple_trigger_reference_change/1
  end

  transformp simple_trigger_config_change do
    pre_process &simple_trigger_config_change_pre_process/1

    keep :object_id, :object_type

    field :trigger_data <- :simple_trigger_container, &SimpleTriggerContainer.encode/1
  end

  transformp trigger_target_change do
    keep :parent_trigger_id, :simple_trigger_id

    field :trigger_target, &encoded_trigger_target/1
  end

  transformp simple_trigger_config_reference_change do
    pre_process &simple_trigger_config_reference_change_pre_process/1

    keep :group

    field :value, &encoded_reference/1
  end

  transformp trigger_target_reference_change do
    field :key <- :simple_trigger_id, &UUID.binary_to_string!/1
  end

  defp simple_trigger_change(%{
         simple_trigger_config: simple_trigger_config,
         trigger_target: trigger_target
       }),
       do:
         simple_trigger_config
         |> simple_trigger_config_change()
         |> Map.merge(trigger_target_change(trigger_target))

  defp simple_trigger_reference_change(%{
         simple_trigger_config: simple_trigger_config,
         trigger_target: trigger_target
       }),
       do:
         simple_trigger_config
         |> simple_trigger_config_reference_change()
         |> Map.merge(trigger_target_reference_change(trigger_target))

  defp simple_trigger_config_change_pre_process(%SimpleTriggerConfig{} = simple_trigger_config),
    do: SimpleTriggerConfig.to_tagged_simple_trigger(simple_trigger_config)

  defp simple_trigger_config_reference_change_pre_process(
         %SimpleTriggerConfig{} = simple_trigger_config
       ),
       do:
         simple_trigger_config
         |> SimpleTriggerConfig.to_tagged_simple_trigger()
         |> Map.put(:group, "simple-triggers-by-uuid")

  defp encoded_trigger_target(%AMQPTriggerTarget{} = trigger_target),
    do:
      TriggerTargetContainer.encode(%TriggerTargetContainer{
        trigger_target: {:amqp_trigger_target, trigger_target}
      })

  defp encoded_reference(%TaggedSimpleTrigger{
         object_id: object_id,
         object_type: object_type
       }),
       do:
         AstarteReference.encode(%AstarteReference{
           object_type: object_type,
           object_uuid: object_id
         })
end
