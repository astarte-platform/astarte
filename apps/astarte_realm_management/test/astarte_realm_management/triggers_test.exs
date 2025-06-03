#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.RealmManagement.TriggersTest do
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.RealmManagement.Engine

  use Astarte.RealmManagement.DataCase, async: true
  use ExUnitProperties

  import Astarte.Fixtures.Trigger
  import Astarte.Fixtures.SimpleTriggerConfig

  describe "Test triggers" do
    @describetag :triggers

    @tag :creation
    property "are installed correctly", %{realm: realm} do
      check all(
              interface <- Astarte.Core.Generators.Interface.interface(),
              device <- Astarte.Core.Generators.Device.device(interfaces: [interface]),
              trigger <- trigger(string(:utf8)),
              policy <- Astarte.Core.Generators.Triggers.Policy.policy(),
              simple_trigger <-
                simple_trigger_config(interface.name, interface.major_version, device.device_id)
            ) do
        _ = Engine.install_trigger_policy(realm, Jason.encode!(policy))

        :ok =
          Engine.install_trigger(
            realm,
            trigger.name,
            policy.name,
            trigger.action,
            serialize_simple_triggers([simple_trigger])
          )

        {:ok,
         %{
           trigger: fetched_trigger,
           serialized_tagged_simple_triggers: serialized_tagged_simple_triggers
         }} =
          Engine.get_trigger(realm, trigger.name)

        assert trigger.action == fetched_trigger.action
        assert trigger.name == fetched_trigger.name
        assert trigger.version == fetched_trigger.version
        assert policy.name == fetched_trigger.policy

        serialized_tagged_simple_triggers =
          serialized_tagged_simple_triggers
          |> Enum.map(fn stst ->
            TaggedSimpleTrigger.decode(stst)
            |> SimpleTriggerConfig.from_tagged_simple_trigger()
          end)

        simple_trigger =
          unless simple_trigger.interface_major,
            do: Map.put(simple_trigger, :interface_major, 0),
            else: simple_trigger

        assert serialized_tagged_simple_triggers == [simple_trigger]

        _ = Engine.delete_trigger(realm, trigger.name)
      end
    end

    @tag :deletion
    property "are deleted correctly", %{realm: realm} do
      check all(
              interface <- Astarte.Core.Generators.Interface.interface(),
              device <- Astarte.Core.Generators.Device.device(interfaces: [interface]),
              trigger <- trigger(string(:utf8)),
              simple_trigger <-
                simple_trigger_config(interface.name, interface.major_version, device.device_id)
            ) do
        :ok =
          Engine.install_trigger(
            realm,
            trigger.name,
            nil,
            trigger.action,
            serialize_simple_triggers([simple_trigger])
          )

        :ok = Engine.delete_trigger(realm, trigger.name)
        assert {:error, :trigger_not_found} = Engine.get_trigger(realm, trigger.name)
      end
    end
  end

  defp serialize_simple_triggers(simple_triggers) do
    simple_triggers
    |> Enum.map(&SimpleTriggerConfig.to_tagged_simple_trigger/1)
    |> Enum.map(&TaggedSimpleTrigger.encode/1)
  end

  # Custom generators
  # TODO remove once `astarte_generators` implements generators for triggers
  defp trigger(name_gen), do: member_of(triggers(name_gen))

  defp simple_trigger_config(interface_name, interface_major, device_id),
    do: member_of(simple_trigger_configs(interface_name, interface_major, device_id))
end
