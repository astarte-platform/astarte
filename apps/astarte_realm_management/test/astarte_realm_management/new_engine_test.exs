#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.EngineTestv2 do
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.RealmManagement.Queries
  alias Astarte.RealmManagement.Engine

  import Astarte.Fixtures.Trigger
  import Astarte.Fixtures.SimpleTriggerConfig

  use Astarte.RealmManagement.DataCase, async: true
  use ExUnitProperties

  describe "Test interface" do
    @describetag :interface

    property "is installed properly", %{realm: realm} do
      check all(interface <- Astarte.Core.Generators.Interface.interface()) do
        json_interface = Jason.encode!(interface)

        _ = Engine.install_interface(realm, json_interface)

        {:ok, fetched_interface} =
          Queries.fetch_interface(realm, interface.name, interface.major_version)

        assert interface.name == fetched_interface.name
        assert interface.major_version == fetched_interface.major_version
        assert interface.minor_version == fetched_interface.minor_version
        assert interface.type == fetched_interface.type
        assert interface.ownership == fetched_interface.ownership
        assert interface.aggregation == fetched_interface.aggregation
        assert interface.description == fetched_interface.description

        fetched_mappings =
          fetched_interface.mappings
          |> Enum.map(&mapping_to_comparable_map/1)
          |> MapSet.new()

        interface_mappings =
          interface.mappings
          |> Enum.map(&mapping_to_comparable_map/1)
          |> MapSet.new()

        assert MapSet.equal?(fetched_mappings, interface_mappings)

        _ = Engine.delete_interface(realm, interface.name, interface.major_version)
      end
    end

    property "does not get deleted if major version is not 0", %{realm: realm} do
      check all(
              interface <-
                Astarte.Core.Generators.Interface.interface(major_version: integer(1..9))
            ) do
        json_interface = Jason.encode!(interface)

        _ = Engine.install_interface(realm, json_interface)

        assert {:error, :forbidden} =
                 Engine.delete_interface(realm, interface.name, interface.major_version)

        {:ok, interfaces} = Engine.get_interfaces_list(realm)
        assert interface.name in interfaces
      end
    end

    property "is deleted if the major version is 0", %{realm: realm} do
      check all(interface <- Astarte.Core.Generators.Interface.interface(major_version: 0)) do
        json_interface = Jason.encode!(interface)

        _ = Engine.install_interface(realm, json_interface)

        assert :ok = Engine.delete_interface(realm, interface.name, interface.major_version)
        {:ok, interfaces} = Engine.get_interfaces_list(realm)
        refute interface.name in interfaces
      end
    end

    property "can update only the same major version", %{realm: realm} do
      check all(
              interface <-
                Astarte.Core.Generators.Interface.interface(major_version: integer(0..8)),
              update_interface <-
                Astarte.Core.Generators.Interface.interface(
                  name: interface.name,
                  major_version: interface.major_version + 1
                )
            ) do
        json_interface = Jason.encode!(interface)
        json_updated_interface = Jason.encode!(update_interface)

        _ = Engine.install_interface(realm, json_interface)

        assert {:error, :interface_major_version_does_not_exist} =
                 Engine.update_interface(realm, json_updated_interface)
      end
    end

    property "is updated with valid update", %{realm: realm} do
      check all(
              interface <-
                Astarte.Core.Generators.Interface.interface(minor_version: integer(1..254)),
              valid_update_interface <-
                Astarte.Core.Generators.Interface.interface(
                  name: interface.name,
                  major_version: interface.major_version,
                  minor_version: integer((interface.minor_version + 1)..255),
                  type: interface.type,
                  ownership: interface.ownership,
                  aggregation: interface.aggregation,
                  interface_id: interface.interface_id,
                  mappings: interface.mappings
                )
            ) do
        json_interface = Jason.encode!(interface)
        json_updated_interface = Jason.encode!(valid_update_interface)

        _ = Engine.install_interface(realm, json_interface)
        :ok = Engine.update_interface(realm, json_updated_interface)

        {:ok, interface} =
          Queries.fetch_interface(realm, interface.name, interface.major_version)

        %{
          name: name,
          major_version: major,
          minor_version: minor
        } = interface

        assert %Astarte.Core.Interface{
                 name: ^name,
                 major_version: ^major,
                 minor_version: ^minor
               } = valid_update_interface
      end
    end

    property "is not updated on downgrade", %{realm: realm} do
      check all(
              interface <-
                Astarte.Core.Generators.Interface.interface(minor_version: integer(2..255)),
              updated_interface <-
                Astarte.Core.Generators.Interface.interface(
                  name: interface.name,
                  major_version: interface.major_version,
                  minor_version: interface.minor_version - 1,
                  type: interface.type,
                  ownership: interface.ownership,
                  aggregation: interface.aggregation,
                  interface_id: interface.interface_id,
                  mappings: interface.mappings
                )
            ) do
        json_interface = Jason.encode!(interface)
        json_updated_interface = Jason.encode!(updated_interface)

        _ = Engine.install_interface(realm, json_interface)
        {:error, :downgrade_not_allowed} = Engine.update_interface(realm, json_updated_interface)
      end
    end
  end

  describe "Test trigger policy" do
    @describetag :trigger_policy

    property "is installed correctly", %{realm: realm} do
      check all(policy <- Astarte.Core.Generators.Triggers.Policy.policy()) do
        policy_json = Jason.encode!(policy)
        :ok = Engine.install_trigger_policy(realm, policy_json)

        {:ok, fetched_policy} = Queries.fetch_trigger_policy(realm, policy.name)

        fetched_policy =
          fetched_policy
          |> PolicyProto.decode()
          |> Policy.from_policy_proto!()

        assert policy.event_ttl == fetched_policy.event_ttl
        assert policy.maximum_capacity == policy.maximum_capacity
        assert policy.name == fetched_policy.name
        assert (policy.prefetch_count || 0) == fetched_policy.prefetch_count
        assert (policy.retry_times || 0) == fetched_policy.retry_times

        assert Enum.sort(policy.error_handlers) == Enum.sort(fetched_policy.error_handlers)
      end
    end

    property "is deleted correctly", %{realm: realm} do
      check all(policy <- Astarte.Core.Generators.Triggers.Policy.policy()) do
        policy_json = Jason.encode!(policy)
        _ = Engine.install_trigger_policy(realm, policy_json)

        :ok = Engine.delete_trigger_policy(realm, policy.name)

        {:error, :trigger_policy_not_found} = Engine.trigger_policy_source(realm, policy.name)
      end
    end
  end

  describe "Test triggers" do
    @describetag :triggers
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

  # Drops virtual and incomparable elements
  defp mapping_to_comparable_map(mapping) do
    Map.from_struct(mapping)
    |> Map.drop([:endpoint_id])
    |> Map.drop([:interface_id])
    |> Map.drop([:path])
    |> Map.drop([:type])
    |> Map.replace_lazy(:doc, fn doc ->
      if is_empty?(doc), do: nil, else: doc
    end)
    |> Map.replace_lazy(:description, fn desc ->
      if is_empty?(desc), do: nil, else: desc
    end)
  end

  defp is_empty?(nil), do: true

  defp is_empty?(string) do
    String.replace(string, " ", "") == ""
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
