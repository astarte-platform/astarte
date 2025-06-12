defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.TriggerHandlerTest do
  @moduledoc false
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.RPC.Server.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.Trigger

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer

  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  use Mimic

  setup_all :populate_interfaces

  setup_all %{realm_name: realm_name, device: device} do
    {:ok, message_tracker} = DataUpdater.fetch_message_tracker(realm_name, device.encoded_id)

    {:ok, dup} =
      DataUpdater.fetch_data_updater_process(realm_name, device.encoded_id, message_tracker, true)

    Astarte.DataAccess.Config
    |> allow(self(), dup)

    GenServer.call(dup, :start)

    %{data_updater: dup}
  end

  property "test 1", context do
    %{realm_name: realm_name, device: device, data_updater: data_updater} = context
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    simple_trigger =
      %SimpleTriggerContainer{
        simple_trigger: {
          :device_trigger,
          %DeviceTrigger{
            device_event_type: :DEVICE_CONNECTED
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    trigger_target =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    check all volatile_trigger <- volatile_trigger(realm_name, device.encoded_id) do
      assert {:ok, _} =
               Trigger.handle_install_volatile_trigger(
                 state,
                 volatile_trigger.object_id,
                 volatile_trigger.object_type,
                 volatile_trigger.parent_id,
                 volatile_trigger.simple_trigger_id,
                 simple_trigger,
                 trigger_target
               )
               |> dbg()
    end
  end

  property "test 2", context do
    %{realm_name: realm_name, device: device, data_updater: data_updater} = context
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    simple_trigger =
      %SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %DataTrigger{
            version: 1,
            interface_name: "com.test.SimpleStreamTest",
            interface_major: 1,
            data_trigger_type: :INCOMING_DATA,
            match_path: "/0/value",
            value_match_operator: :LESS_THAN,
            known_value: Cyanide.encode!(%{v: 100})
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    trigger_target =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    check all volatile_trigger <- volatile_trigger(realm_name, device.encoded_id) do
      assert {:ok, _} =
               Trigger.handle_install_volatile_trigger(
                 state,
                 volatile_trigger.object_id,
                 volatile_trigger.object_type,
                 volatile_trigger.parent_id,
                 volatile_trigger.simple_trigger_id,
                 simple_trigger,
                 trigger_target
               )
               |> dbg()
    end
  end

  property "test 2 bis", context do
    %{
      realm_name: realm_name,
      device: device,
      data_updater: data_updater,
      individual_properties_server_interface: individual_properties_server_interface
    } = context

    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    simple_trigger =
      %SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %DataTrigger{
            version: 1,
            interface_name: individual_properties_server_interface.name,
            interface_major: 1,
            data_trigger_type: :INCOMING_DATA,
            match_path: "/*",
            value_match_operator: :LESS_THAN,
            known_value: Cyanide.encode!(%{v: 100})
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    trigger_target =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    check all volatile_trigger <- volatile_trigger(realm_name, device.encoded_id) do
      assert {:ok, _} =
               Trigger.handle_install_volatile_trigger(
                 state,
                 volatile_trigger.object_id,
                 volatile_trigger.object_type,
                 volatile_trigger.parent_id,
                 volatile_trigger.simple_trigger_id,
                 simple_trigger,
                 trigger_target
               )
               |> dbg()
    end
  end

  property "test 3", context do
    %{realm_name: realm_name, device: device, data_updater: data_updater} = context
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    simple_trigger =
      %SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %DataTrigger{
            version: 1,
            interface_name: "*",
            interface_major: 1,
            data_trigger_type: :INCOMING_DATA,
            match_path: "/0/value",
            value_match_operator: :LESS_THAN,
            known_value: Cyanide.encode!(%{v: 100})
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    trigger_target =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    check all volatile_trigger <- volatile_trigger(realm_name, device.encoded_id) do
      assert {:ok, _} =
               Trigger.handle_install_volatile_trigger(
                 state,
                 volatile_trigger.object_id,
                 volatile_trigger.object_type,
                 volatile_trigger.parent_id,
                 volatile_trigger.simple_trigger_id,
                 simple_trigger,
                 trigger_target
               )
               |> dbg()
    end
  end

  defp volatile_trigger(realm_name, encoded_device_id) do
    gen all object_id <- uuid(),
            object_type <- integer(),
            parent_id <- uuid(),
            trigger_id <- uuid(),
            trigger_target <- binary() do
      %{
        realm_name: realm_name,
        device_id: encoded_device_id,
        object_id: object_id,
        object_type: object_type,
        parent_id: parent_id,
        simple_trigger_id: trigger_id
      }
    end
  end

  defp uuid, do: repeatedly(&Ecto.UUID.bingenerate/0)
end
