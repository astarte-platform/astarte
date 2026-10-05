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

defmodule Astarte.RPC.VolatileTriggers.ClientTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Events.Triggers, as: EventsTriggers
  alias Astarte.RPC.VolatileTriggers
  alias Astarte.RPC.VolatileTriggers.Client

  setup_all do
    client = start_link_supervised!(Client)

    %{client: client}
  end

  setup_all :add_fixtures

  setup %{client: client} do
    Mimic.allow(EventsTriggers, self(), client)

    :ok
  end

  describe "trigger installation" do
    test "calls astarte events", context do
      %{realm_name: realm_name, tagged_device_simple_trigger: trigger, trigger_target: target} =
        context

      test_process = self()

      EventsTriggers
      |> expect(:install_volatile_trigger, fn ^realm_name, ^trigger, ^target, _data ->
        send(test_process, :volatile_trigger_installed)
        :ok
      end)

      VolatileTriggers.install(realm_name, trigger, target)
      assert_receive :volatile_trigger_installed, 1000
    end
  end

  describe "trigger deletion" do
    test "calls astarte events", context do
      %{realm_name: realm_name, trigger_target: target} =
        context

      test_process = self()
      trigger_id = target.simple_trigger_id

      EventsTriggers
      |> expect(:delete_volatile_trigger, fn ^realm_name, ^trigger_id ->
        send(test_process, :volatile_trigger_deleted)
        :ok
      end)

      VolatileTriggers.delete(realm_name, trigger_id)
      assert_receive :volatile_trigger_deleted, 1000
    end
  end

  defp add_fixtures(_context) do
    realm_name = "my-realm"

    tagged_device_simple_trigger = %{
      simple_trigger_container: %{
        simple_trigger: {:device_trigger, %{device_event_type: :INTERFACE_ADDED}}
      }
    }

    tagged_data_simple_trigger = %{
      simple_trigger_container: %{
        simple_trigger: {:data_trigger, %{interface_name: "*", data_trigger_type: :INCOMING_DATA}}
      }
    }

    trigger_target = %AMQPTriggerTarget{
      simple_trigger_id: UUID.uuid4(),
      parent_trigger_id: UUID.uuid4(),
      routing_key: "routing_key",
      static_headers: %{},
      exchange: "exchange",
      message_expiration_ms: 30_000,
      message_priority: 1,
      message_persistent: true
    }

    %{
      realm_name: realm_name,
      tagged_device_simple_trigger: tagged_device_simple_trigger,
      tagged_data_simple_trigger: tagged_data_simple_trigger,
      trigger_target: trigger_target
    }
  end
end
