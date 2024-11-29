# Copyright 2024 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

defmodule Astarte.DataUpdaterPlant.VolatileTriggerHandlerTest do
  use ExUnit.Case

  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.VolatileTriggerHandler
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.RPC.Protocol.DataUpdaterPlant.InstallVolatileTrigger
  alias Astarte.RPC.Protocol.DataUpdaterPlant.DeleteVolatileTrigger
  alias AMQPTestHelper

  setup_all do
    {:ok, _client} = Astarte.DataUpdaterPlant.DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      Astarte.DataUpdaterPlant.DatabaseTestHelper.destroy_local_test_keyspace()
    end)
  end

  setup do
    realm = "autotestrealm"

    random_device =
      Device.random_device_id()
      |> Device.encode_device_id()

    %{realm: realm, encoded_device_id: random_device}
  end

  # TODO: add happy path test
  test "fails to install volatile trigger on missing device", %{
    realm: realm,
    encoded_device_id: fail_encoded_device_id
  } do
    simple_trigger = simple_trigger_fixture()
    trigger_target = trigger_target_fixture()
    volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
    volatile_trigger_id = :crypto.strong_rand_bytes(16)

    {:ok, fail_device_id} = Device.decode_device_id(fail_encoded_device_id)

    fail_install_volatile_trigger_data = %InstallVolatileTrigger{
      realm_name: realm,
      device_id: fail_encoded_device_id,
      object_id: fail_device_id,
      object_type: 1,
      parent_id: volatile_trigger_parent_id,
      simple_trigger_id: volatile_trigger_id,
      simple_trigger: simple_trigger,
      trigger_target: trigger_target
    }

    assert VolatileTriggerHandler.install_volatile_trigger(fail_install_volatile_trigger_data) ==
             {:error, :device_does_not_exist}
  end

  # TODO: add happy path test
  test "fails to delete volatile trigger on missing device", %{
    realm: realm,
    encoded_device_id: fail_encoded_device_id
  } do
    volatile_trigger_id = :crypto.strong_rand_bytes(16)

    fail_delete_volatile_trigger_data = %DeleteVolatileTrigger{
      realm_name: realm,
      device_id: fail_encoded_device_id,
      trigger_id: volatile_trigger_id
    }

    assert VolatileTriggerHandler.delete_volatile_trigger(fail_delete_volatile_trigger_data) ==
             {:error, :device_does_not_exist}
  end

  defp simple_trigger_fixture() do
    # TODO: make this more random, possibly using StreamData
    %SimpleTriggerContainer{
      simple_trigger: {
        :device_trigger,
        %DeviceTrigger{
          device_event_type: :DEVICE_CONNECTED
        }
      }
    }
    |> SimpleTriggerContainer.encode()
  end

  defp trigger_target_fixture() do
    # TODO: make this more random, possibly using StreamData
    %TriggerTargetContainer{
      trigger_target: {
        :amqp_trigger_target,
        %AMQPTriggerTarget{
          routing_key: AMQPTestHelper.events_routing_key()
        }
      }
    }
    |> TriggerTargetContainer.encode()
  end
end
