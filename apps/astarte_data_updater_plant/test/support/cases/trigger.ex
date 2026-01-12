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

defmodule Astarte.Cases.Trigger do
  use ExUnit.CaseTemplate

  alias Astarte.Core.Generators.Realm, as: RealmGenerator
  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.Events.Triggers.Cache

  using do
    quote do
      import Astarte.Cases.Trigger
    end
  end

  setup_all context do
    realm_name = Map.get(context, :realm_name, RealmGenerator.realm_name() |> Enum.at(0))
    trigger_id = UUID.uuid4(:raw)
    tagged_simple_trigger = %TaggedSimpleTrigger{}
    trigger_target = %AMQPTriggerTarget{}
    policy = PolicyGenerator.policy() |> Enum.at(0) |> Map.fetch!(:name)
    data = %State{} |> Map.from_struct()
    install_trigger_message = {realm_name, tagged_simple_trigger, trigger_target, policy, data}
    delete_trigger_message = {realm_name, trigger_id, tagged_simple_trigger, data}

    %{
      data: data,
      trigger_id: trigger_id,
      install_trigger_message: install_trigger_message,
      delete_trigger_message: delete_trigger_message,
      policy: policy,
      realm_name: realm_name,
      tagged_simple_trigger: tagged_simple_trigger,
      trigger_target: trigger_target
    }
  end

  setup %{realm_name: realm_name} do
    Cache.reset_realm_cache(realm_name)

    :ok
  end

  defp mock_trigger_target(routing_key) do
    %AMQPTriggerTarget{
      parent_trigger_id: :uuid.get_v4(),
      simple_trigger_id: :uuid.get_v4(),
      static_headers: %{},
      routing_key: routing_key
    }
  end

  def install_volatile_trigger(state, protobuf_trigger, validation_function \\ nil) do
    id = System.unique_integer()
    test_process = self()
    ref = {:event_dispatched, id}
    trigger_target = mock_trigger_target("target#{id}")

    deserialized_simple_trigger =
      case protobuf_trigger do
        %DeviceTrigger{} -> {{:device_trigger, protobuf_trigger}, trigger_target}
        %DataTrigger{} -> {{:data_trigger, protobuf_trigger}, trigger_target}
      end

    Astarte.Events.TriggersHandler
    |> Mimic.stub(:dispatch_event, fn
      event, event_type, ^trigger_target, realm, hw_id, timestamp, policy ->
        validation_function &&
          validation_function.(event, event_type, realm, hw_id, timestamp, policy)

        send(test_process, ref)
    end)

    Astarte.Events.Triggers.install_volatile_trigger(
      state.realm,
      deserialized_simple_trigger,
      Map.from_struct(state)
    )

    ref
  end
end
