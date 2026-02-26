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

defmodule Astarte.Events.TriggersHandlerTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Events.TriggersHandler
  alias Astarte.Events.TriggersHandler.Core

  setup :verify_on_exit!

  @device_id "f0VMRgIBAQAAAAAAAAAAAA"
  @timestamp 1_700_000_000
  @policy_name "test_policy"

  setup_all do
    realm = "autotestrealm#{System.unique_integer([:positive])}"

    target = %AMQPTriggerTarget{
      simple_trigger_id: UUID.uuid4(:raw),
      parent_trigger_id: UUID.uuid4(:raw)
    }

    {:ok, realm: realm, target: target}
  end

  describe "register_target/2" do
    test "register_target/2 delegates to Core", %{realm: realm, target: target} do
      Core |> expect(:register_target, fn _realm, ^target -> :ok end)
      assert TriggersHandler.register_target(realm, target) == :ok
    end
  end

  describe "dispatch_event/7" do
    test "builds a SimpleEvent and delegates to Core.dispatch_event/3", %{
      realm: realm,
      target: target
    } do
      event = %{some: "payload"}
      event_type = :device_connected_event

      Core
      |> expect(:dispatch_event, fn %SimpleEvent{} = simple_event, tgt, policy ->
        # target and policy are passed through unchanged
        assert tgt == target
        assert policy == @policy_name

        # SimpleEvent fields
        assert simple_event.realm == realm
        assert simple_event.device_id == @device_id
        assert simple_event.timestamp == @timestamp
        assert simple_event.simple_trigger_id == target.simple_trigger_id
        assert simple_event.parent_trigger_id == target.parent_trigger_id
        assert simple_event.event == {event_type, event}

        :ok
      end)

      assert TriggersHandler.dispatch_event(
               event,
               event_type,
               target,
               realm,
               @device_id,
               @timestamp,
               @policy_name
             ) == :ok
    end

    test "passes nil policy_name to Core.dispatch_event/3", %{realm: realm, target: target} do
      event = %{foo: :bar}
      event_type = :incoming_data_event

      Core
      |> expect(:dispatch_event, fn %SimpleEvent{}, ^target, nil ->
        :ok
      end)

      assert TriggersHandler.dispatch_event(
               event,
               event_type,
               target,
               realm,
               @device_id,
               @timestamp,
               nil
             ) == :ok
    end
  end
end
