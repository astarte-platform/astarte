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

defmodule Astarte.DataAccess.Adapters.Triggers.TriggerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.Trigger
  import Astarte.DataAccess.Adapters.Triggers.Trigger

  alias Astarte.Core.Triggers.Trigger
  alias Astarte.DataAccess.KvStore

  describe "from core trigger to key-value changes" do
    property "maps a trigger and its optional policy links" do
      check all %Trigger{name: name, policy: policy, trigger_uuid: trigger_uuid} = source <-
                  trigger(policy: policy()) do
        %{
          policy_links: policy_links,
          trigger: %{value: encoded_trigger} = trigger,
          trigger_by_name: trigger_by_name
        } = from_core_trigger_to_change(source)

        trigger_uuid_string = UUID.binary_to_string!(trigger_uuid)

        for changes <- [trigger, trigger_by_name | policy_links] do
          assert %KvStore{} = struct(KvStore, Map.take(changes, [:group, :key, :value]))
        end

        assert Trigger.decode(encoded_trigger) == source

        assert trigger == %{
                 group: "triggers",
                 key: trigger_uuid_string,
                 value: Trigger.encode(source)
               }

        assert trigger_by_name == %{
                 group: "triggers-by-name",
                 key: name,
                 value: trigger_uuid,
                 value_type: :uuid
               }

        assert policy_links == policy_links(trigger_uuid_string, policy)
      end
    end
  end

  defp policy do
    one_of([
      constant(nil),
      constant(""),
      string(:alphanumeric, min_length: 1, max_length: 128)
    ])
  end

  defp policy_links(_trigger_uuid, policy) when policy in [nil, ""], do: []

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
