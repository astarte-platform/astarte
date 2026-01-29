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

defmodule Astarte.Events.Triggers.CacheTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Cache

  import Mimic

  alias Astarte.Events.Triggers.Cache
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Events.AMQP.Vhost
  alias Astarte.Events.AMQPTriggers.VHostSupervisor
  alias Astarte.Events.Triggers

  setup_all context do
    %{realm_name: realm_name} = context

    :ok = Vhost.create_vhost(realm_name)
    {:ok, producer} = VHostSupervisor.for_realm(realm_name, true)

    Astarte.DataAccess.Config
    |> allow(self(), producer)

    :ok = GenServer.call(producer, :start)

    :ok
  end

  describe "find_device_trigger_targets/4" do
    test "loads triggers from DB and caches them", %{realm_name: realm} do
      device_id = DeviceGenerator.id() |> Enum.at(0)
      _simple_trigger = install_simple_trigger(realm, object: {:device_id, device_id})

      targets =
        Cache.find_device_trigger_targets(
          realm,
          device_id,
          [],
          :on_device_connection
        )

      assert length(targets) == 1
    end

    test "loads device triggers for groups", %{realm_name: realm} do
      group = "my_group"
      device_id = DeviceGenerator.id() |> Enum.at(0)

      _trigger = install_simple_trigger(realm, object: {:group, group})

      targets =
        Cache.find_device_trigger_targets(
          realm,
          device_id,
          [group],
          :on_device_connection
        )

      assert length(targets) == 1
    end
  end

  test "installs and deletes volatile triggers", %{realm_name: realm} do
    device_id = DeviceGenerator.id() |> Enum.at(0)
    event_key = :on_device_connection
    default_trigger = install_simple_trigger(realm, object: {:device_id, device_id})
    simple_trigger = Triggers.deserialize_simple_trigger(default_trigger)

    {{trigger_type, trigger}, target} = simple_trigger

    :ok =
      Cache.install_volatile_trigger(
        realm,
        event_key,
        {:device_id, device_id},
        trigger_type,
        trigger,
        target,
        "policy1"
      )

    targets =
      Cache.find_device_trigger_targets(
        realm,
        device_id,
        [],
        event_key
      )

    assert length(targets) == 2

    :ok = Cache.delete_volatile_trigger(realm, default_trigger.simple_trigger_id)

    targets_after_delete =
      Cache.find_device_trigger_targets(
        realm,
        device_id,
        [],
        event_key
      )

    assert length(targets_after_delete) == 1
  end

  describe "find_data_triggers/4" do
    test "loads data triggers from DB", %{realm_name: realm} do
      device_id = DeviceGenerator.id() |> Enum.at(0)
      interface = install_interface(realm)

      _trigger =
        install_data_trigger(realm,
          object: {:device_and_any_interface, device_id},
          interface_name: interface.name,
          interface_major: interface.major_version
        )

      {:ok, interface_id} = Astarte.DataAccess.UUID.cast(interface.interface_id)

      targets =
        Cache.find_data_trigger_targets(
          realm,
          device_id,
          [],
          {:on_incoming_data, interface_id, :any_endpoint},
          %{}
        )

      assert length(targets) == 1
    end
  end
end
