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

defmodule Astarte.RealmManagement.Helpers.Triggers do
  @moduledoc false
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Events.Triggers, as: EventsTriggers
  alias Astarte.Events.Triggers.Cache
  alias Astarte.Events.TriggersHandler
  alias Astarte.RealmManagement.Triggers, as: RMTriggers

  def reset_cache(realm_name) do
    Cache.reset_realm_cache(realm_name)
  end

  def rpc_trigger_client do
    Astarte.RealmManagement.Supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(fn {id, pid, _type, _mod} ->
      id == Astarte.RPC.Triggers.Client && pid
    end)
  end

  def register_device_deletion_started_trigger(realm_name, conditions) do
    register_device_trigger(
      realm_name,
      "device_deletion_started",
      :device_deletion_started_event,
      conditions
    )
  end

  def register_device_deletion_started_volatile_trigger(realm_name, conditions) do
    register_device_volatile_trigger(
      realm_name,
      "device_deletion_started",
      :device_deletion_started_event,
      conditions
    )
  end

  def register_device_deletion_finished_trigger(realm_name, conditions) do
    register_device_trigger(
      realm_name,
      "device_deletion_finished",
      :device_deletion_finished_event,
      conditions
    )
  end

  def register_device_deletion_finished_volatile_trigger(realm_name, conditions) do
    register_device_volatile_trigger(
      realm_name,
      "device_deletion_finished",
      :device_deletion_finished_event,
      conditions
    )
  end

  defp register_device_trigger(realm_name, on_condition, event_type, conditions) do
    trigger_params = %{
      "action" => %{"http_post_url" => "http://astarte-platform.org"},
      "name" => "#{on_condition}_#{System.unique_integer([:positive])}",
      "simple_triggers" => [device_trigger_params(on_condition, conditions)]
    }

    RMTriggers.create_trigger(realm_name, trigger_params)

    ref = {:device_trigger_received, System.unique_integer()}
    stub_dispatch_event(event_type, realm_name, ref)

    ref
  end

  defp register_device_volatile_trigger(realm_name, on_condition, event_type, conditions) do
    tagged_simple_trigger =
      %SimpleTriggerConfig{}
      |> SimpleTriggerConfig.changeset(device_trigger_params(on_condition, conditions))
      |> Ecto.Changeset.apply_action!(:insert)
      |> SimpleTriggerConfig.to_tagged_simple_trigger()

    EventsTriggers.install_volatile_trigger(
      realm_name,
      tagged_simple_trigger,
      mock_amqp_trigger_target(),
      %{}
    )

    ref = {:device_volatile_trigger_received, System.unique_integer()}
    stub_dispatch_event(event_type, realm_name, ref)

    ref
  end

  defp device_trigger_params(on_condition, conditions) do
    conditions
    |> Map.new(fn {condition_type, condition_value} ->
      {to_string(condition_type), condition_value}
    end)
    |> Map.merge(%{"type" => "device_trigger", "on" => on_condition})
  end

  # signal to test process that 'the trigger fired'
  defp stub_dispatch_event(event_type, realm_name, ref) do
    test_process = self()

    Mimic.stub(TriggersHandler, :dispatch_event, fn _event,
                                                    ^event_type,
                                                    _target,
                                                    ^realm_name,
                                                    _device_id,
                                                    _timpestamp,
                                                    _policy ->
      send(test_process, ref)
    end)
  end

  defp mock_amqp_trigger_target do
    %AMQPTriggerTarget{
      parent_trigger_id: UUID.uuid4(:raw),
      simple_trigger_id: UUID.uuid4(:raw),
      static_headers: %{},
      routing_key: "volatile_trigger_test"
    }
  end
end
