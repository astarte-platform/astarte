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

    pre_process &pre_process/1

    keep :trigger, :trigger_by_name, :policy_links
  end

  defp pre_process(%Trigger{name: name, policy: policy, trigger_uuid: trigger_uuid} = trigger) do
    trigger_uuid_string = UUID.binary_to_string!(trigger_uuid)

    %{
      trigger: %{
        group: "triggers",
        key: trigger_uuid_string,
        value: Trigger.encode(trigger)
      },
      trigger_by_name: %{
        group: "triggers-by-name",
        key: name,
        value: trigger_uuid,
        value_type: :uuid
      },
      policy_links: policy_links(trigger_uuid_string, policy)
    }
  end

  defp policy_links(_trigger_uuid, nil), do: []
  defp policy_links(_trigger_uuid, ""), do: []

  defp policy_links(trigger_uuid, policy) do
    [
      %{
        group: "triggers-with-policy-#{policy}",
        key: trigger_uuid,
        value: trigger_uuid,
        value_type: :uuid
      },
      %{
        group: "trigger_to_policy",
        key: trigger_uuid,
        value: policy
      }
    ]
  end
end
