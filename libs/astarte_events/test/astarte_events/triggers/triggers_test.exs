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

defmodule Astarte.Events.TriggersTest do
  use Astarte.Cases.Data, async: true
  import Mimic

  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils
  alias Astarte.DataAccess.UUID, as: AstarteUUID
  alias Astarte.Events.AMQP.Vhost
  alias Astarte.Events.AMQPTriggers.VHostSupervisor
  alias Astarte.Events.Test.AmqpTriggers.Consumer
  alias Astarte.Events.Triggers
  alias Astarte.Events.Triggers.DataTriggerContext

  @routing_key "test.routing.key"

  setup :verify_on_exit!

  setup_all context do
    %{realm_name: realm_name} = context

    :ok = Vhost.create_vhost(realm_name)
    {:ok, producer} = VHostSupervisor.for_realm(realm_name, true)

    Astarte.DataAccess.Config
    |> allow(self(), producer)

    :ok = GenServer.call(producer, :start)

    :ok
  end

  setup context do
    realm_name = context[:realm_name]
    routing_key = context[:routing_key] || @routing_key
    test_process = self()

    opts = [
      realm_name: realm_name,
      routing_key: routing_key,
      ready_pid: test_process,
      wait_start: true,
      message_handler: fn payload, meta ->
        send(test_process, {:amqp_message, payload, meta})
        :ok
      end
    ]

    consumer = start_supervised!({Consumer, opts})

    Astarte.DataAccess.Config
    |> allow(self(), consumer)

    :ok = GenServer.call(consumer, :start)

    assert_receive :consumer_ready

    %{amqp_consumer: consumer, realm_name: realm_name}
  end

  describe "install_triggers" do
    test "installs and deletes a simple trigger", %{realm_name: realm} do
      device_id = DeviceGenerator.id() |> Enum.at(0)

      trigger_container = %{
        simple_trigger: {:device_trigger, %{device_event_type: :DEVICE_CONNECTED}}
      }

      tagged_simple_trigger = %TaggedSimpleTrigger{
        object_type: Utils.object_type_to_int!(:device_and_any_interface),
        object_id: device_id,
        simple_trigger_container: trigger_container
      }

      target = %{
        routing_key: "test_events_#{realm}",
        exchange: "astarte_events_#{realm}"
      }

      policy = "test_policy"

      assert :ok =
               Triggers.install_trigger(
                 realm,
                 tagged_simple_trigger,
                 target,
                 policy
               )

      assert :ok =
               Triggers.delete_trigger(
                 realm,
                 UUID.uuid4(:raw),
                 tagged_simple_trigger
               )
    end

    test "installs and deletes volatile triggers", %{realm_name: realm} do
      device_id = DeviceGenerator.id() |> Enum.at(0)
      event_key = :on_device_connection
      default_trigger = install_simple_trigger(realm, object: {:device_id, device_id})
      simple_trigger = Triggers.deserialize_simple_trigger(default_trigger)

      :ok =
        Triggers.install_volatile_trigger(
          realm,
          simple_trigger,
          %{}
        )

      targets =
        Triggers.find_device_trigger_targets(
          realm,
          device_id,
          [],
          event_key
        )

      assert length(targets) == 2

      :ok = Triggers.delete_volatile_trigger(realm, default_trigger.simple_trigger_id)

      targets_after_delete =
        Triggers.find_device_trigger_targets(
          realm,
          device_id,
          [],
          event_key
        )

      assert length(targets_after_delete) == 1
    end
  end

  describe "fetch_triggers" do
    test "fetch_triggers/2 returns device triggers", %{realm_name: realm} do
      device_id = DeviceGenerator.id() |> Enum.at(0)
      simple_trigger = install_simple_trigger(realm, object: {:device_id, device_id})

      deserialized = Triggers.deserialize_simple_trigger(simple_trigger)

      assert {:ok, data} = Triggers.fetch_triggers(realm, [deserialized])
      assert length(data.device_triggers[:on_device_connection]) == 1
    end

    test "fetch_triggers/3 returns data triggers", %{realm_name: realm} do
      simple_trigger = install_data_trigger(realm)

      deserialized = Triggers.deserialize_simple_trigger(simple_trigger)

      assert {:ok, data} = Triggers.fetch_triggers(realm, [deserialized], %{})

      [data_trigger] = data.data_triggers[{:on_incoming_data, :any_interface, :any_endpoint}]
      assert length(data_trigger.trigger_targets) == 1
    end
  end

  describe "find_data_triggers" do
    test "loads data triggers from DB", %{realm_name: realm} do
      device_id = DeviceGenerator.id() |> Enum.at(0)
      interface = install_interface(realm)

      _trigger =
        install_data_trigger(realm,
          object: {:device_and_any_interface, device_id},
          interface_name: interface.name,
          interface_major: interface.major_version
        )

      {:ok, interface_id} = AstarteUUID.cast(interface.interface_id)

      targets =
        Triggers.find_data_trigger_targets(
          realm,
          device_id,
          [],
          {:on_incoming_data, interface_id, :any_endpoint},
          %{}
        )

      assert length(targets) == 1
    end
  end

  describe "find_interface_event_device_trigger_targets" do
    test "returns targets", %{realm_name: realm} do
      device_id = DeviceGenerator.id() |> Enum.at(0)
      interface = install_interface(realm)
      {:ok, interface_id} = AstarteUUID.cast(interface.interface_id)

      _trigger =
        install_simple_trigger(realm,
          object: {:device_id, device_id},
          event: :INTERFACE_ADDED
        )

      targets =
        Triggers.find_interface_event_device_trigger_targets(
          realm,
          device_id,
          [],
          :on_interface_added,
          interface_id
        )

      assert length(targets) == 1
    end
  end

  describe "find_all_data_triggers" do
    test "returns targets", %{realm_name: realm} do
      device_id = DeviceGenerator.id() |> Enum.at(0)
      interface = install_interface(realm)

      _trigger =
        install_data_trigger(realm,
          object: {:device_and_any_interface, device_id},
          interface_name: interface.name,
          interface_major: interface.major_version
        )

      {:ok, interface_id} = AstarteUUID.cast(interface.interface_id)

      query = %DataTriggerContext{
        realm_name: realm,
        device_id: device_id,
        groups: [],
        event: :on_incoming_data,
        interface_id: interface_id,
        endpoint_id: :any_endpoint,
        path: "",
        value: "",
        data: %{}
      }

      targets = Triggers.find_all_data_trigger_targets(query)

      assert Enum.any?(targets)
    end
  end
end
