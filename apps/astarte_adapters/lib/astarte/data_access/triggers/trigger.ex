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

defmodule Astarte.DataAccess.Adapters.Triggers.Trigger do
  @moduledoc """
  Mappings from Astarte triggers to their key-value entries.
  """
  use Astarte.Adapters

  alias Astarte.Core.Triggers.Trigger

  @type changes :: %{
          trigger: map(),
          trigger_by_name: map(),
          policy_links: [map()]
        }

  transform from_core_trigger_to_change do
    @source Trigger.t()
    @returns changes()

    field :trigger, &trigger_change/1
    field :trigger_by_name, &trigger_by_name_change/1
    field :policy_links, &policy_links/1
  end

  transformp trigger_change do
    pre_process &trigger_change_pre_process/1

    keep :group

    field :key <- :trigger_uuid, &UUID.binary_to_string!/1
    field :value, &Trigger.encode/1
  end

  transformp trigger_by_name_change do
    pre_process &trigger_by_name_change_pre_process/1

    keep :group, :value_type

    field :key <- :name
    field :value <- :trigger_uuid
  end

  transformp trigger_policy_index_change do
    pre_process &trigger_policy_index_change_pre_process/1

    keep :group, :value_type

    field :key <- :trigger_uuid, &UUID.binary_to_string!/1
    field :value <- :trigger_uuid, &UUID.binary_to_string!/1
  end

  transformp trigger_policy_reference_change do
    pre_process &trigger_policy_reference_change_pre_process/1

    keep :group

    field :key <- :trigger_uuid, &UUID.binary_to_string!/1
    field :value <- :policy
  end

  defp trigger_change_pre_process(%Trigger{} = trigger),
    do: Map.put(trigger, :group, "triggers")

  defp trigger_by_name_change_pre_process(%Trigger{} = trigger),
    do: Map.merge(trigger, %{group: "triggers-by-name", value_type: :uuid})

  defp trigger_policy_index_change_pre_process(%Trigger{policy: policy} = trigger),
    do: Map.merge(trigger, %{group: "triggers-with-policy-#{policy}", value_type: :uuid})

  defp trigger_policy_reference_change_pre_process(%Trigger{} = trigger),
    do: Map.put(trigger, :group, "trigger_to_policy")

  defp policy_links(%Trigger{policy: nil}), do: []
  defp policy_links(%Trigger{policy: ""}), do: []

  defp policy_links(%Trigger{} = trigger) do
    [
      trigger_policy_index_change(trigger),
      trigger_policy_reference_change(trigger)
    ]
  end
end
