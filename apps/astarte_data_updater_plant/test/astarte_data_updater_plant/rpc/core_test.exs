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

defmodule Astarte.DataUpdaterPlant.RPC.CoreTest do
  @moduledoc false
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.RPC.Replica
  alias Astarte.DataUpdaterPlant.RPC.Server.Core

  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  use Mimic

  setup_all %{realm_name: realm_name, device: device} do
    {:ok, message_tracker} = DataUpdater.fetch_message_tracker(realm_name, device.encoded_id)

    {:ok, dup} =
      DataUpdater.fetch_data_updater_process(realm_name, device.encoded_id, message_tracker, true)

    Astarte.DataAccess.Config
    |> allow(self(), dup)

    GenServer.call(dup, :start)

    %{data_updater: dup}
  end

  property "install_volatile_trigger/1 calls the `data_updater` server", context do
    %{realm_name: realm_name, device: device, data_updater: data_updater} = context

    check all volatile_trigger <- volatile_trigger(realm_name, device.encoded_id) do
      expected_request =
        {:handle_install_volatile_trigger, volatile_trigger.parent_id,
         volatile_trigger.simple_trigger_id, volatile_trigger.simple_trigger,
         volatile_trigger.trigger_target}

      expected_pid = self()

      DataUpdater.Server
      |> allow(self(), data_updater)
      |> expect(:handle_call, fn ^expected_request, {^expected_pid, _}, state ->
        {:reply, {:ok, true}, state}
      end)

      assert {:ok, _} = Core.install_volatile_trigger(volatile_trigger)
    end
  end

  property "delete_volatile_trigger/1 calls the `data_updater` server", context do
    %{realm_name: realm_name, device: device, data_updater: data_updater} = context

    check all trigger_id <- binary() do
      expected_request =
        {:handle_delete_volatile_trigger, trigger_id}

      expected_pid = self()

      DataUpdater.Server
      |> allow(self(), data_updater)
      |> expect(:handle_call, fn ^expected_request, {^expected_pid, _}, state ->
        {:reply, {:ok, true}, state}
      end)

      assert {:ok, _} =
               Core.delete_volatile_trigger(%{
                 realm_name: realm_name,
                 device_id: device.encoded_id,
                 trigger_id: trigger_id
               })
    end
  end

  describe "install_trigger/4" do
    setup do
      test_process = self()

      Replica
      |> Mimic.stub(:send_all_replicas, fn _message ->
        send(test_process, :sent_all_replicas)
        :ok
      end)

      :ok
    end

    test "sends an install trigger message to all the replicas for device triggers", context do
      %{
        realm_name: realm_name
      } = context

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger: {:device_trigger, nil}
        }
      }

      Core.install_trigger(realm_name, tagged_simple_trigger, nil, nil)

      assert_receive :sent_all_replicas
    end

    test "sends an install trigger message to all the replicas for all interface data triggers",
         context do
      %{
        realm_name: realm_name
      } = context

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger: {:data_trigger, %{interface_name: "*"}}
        }
      }

      Core.install_trigger(realm_name, tagged_simple_trigger, nil, nil)

      assert_receive :sent_all_replicas
    end

    test "sends an install trigger message to all the replicas for all paths data triggers",
         context do
      %{
        realm_name: realm_name
      } = context

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger: {:data_trigger, %{match_path: "/*"}}
        }
      }

      Core.install_trigger(realm_name, tagged_simple_trigger, nil, nil)

      assert_receive :sent_all_replicas
    end

    test "sends an install trigger message to all the replicas for path specific data triggers",
         context do
      %{
        realm_name: realm_name,
        fixed_endpoint_interface: interface
      } = context

      interface_specific_trigger = %{
        interface_name: interface.name,
        interface_major: interface.major_version,
        match_path: "/value"
      }

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger: {:data_trigger, interface_specific_trigger}
        }
      }

      Core.install_trigger(realm_name, tagged_simple_trigger, nil, nil)

      assert_receive :sent_all_replicas
    end

    test "does nothing if the interfaces can't be found", context do
      %{
        realm_name: realm_name
      } = context

      # an invalid interface is not installed
      invalid_interface_data_trigger =
        %{
          interface_name: ".",
          interface_major: 1,
          match_path: "/value"
        }

      tagged_simple_trigger_with_interface_not_installed = %{
        simple_trigger_container: %{
          simple_trigger: {:data_trigger, invalid_interface_data_trigger}
        }
      }

      Mimic.reject(&Replica.send_all_replicas/1)

      assert {:error, :interface_not_found} ==
               Core.install_trigger(
                 realm_name,
                 tagged_simple_trigger_with_interface_not_installed,
                 nil,
                 nil
               )
    end
  end

  defp volatile_trigger(realm_name, device_id) do
    gen all object_id <- uuid(),
            object_type <- integer(),
            parent_id <- uuid(),
            trigger_id <- uuid(),
            simple_trigger <- binary(),
            trigger_target <- binary() do
      %{
        realm_name: realm_name,
        device_id: device_id,
        object_id: object_id,
        object_type: object_type,
        parent_id: parent_id,
        simple_trigger_id: trigger_id,
        simple_trigger: simple_trigger,
        trigger_target: trigger_target
      }
    end
  end

  defp uuid, do: repeatedly(&Ecto.UUID.bingenerate/0)
end
