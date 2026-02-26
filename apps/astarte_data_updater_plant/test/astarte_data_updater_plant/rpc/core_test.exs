#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.RPC.Server.Core

  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Trigger
  use Astarte.Cases.Device
  use Astarte.Cases.DataUpdater
  use ExUnitProperties

  use Mimic

  property "install_volatile_trigger/1 calls the `data_updater`", context do
    %{realm_name: realm_name, device: device} = context

    check all volatile_trigger <- volatile_trigger(realm_name, device.encoded_id) do
      expected_signal =
        {:install_volatile_trigger, volatile_trigger.parent_id,
         volatile_trigger.simple_trigger_id, volatile_trigger.simple_trigger,
         volatile_trigger.trigger_target}

      Impl
      |> expect(:handle_signal, fn ^expected_signal, state -> {:ok, state} end)

      assert :ok = Core.install_volatile_trigger(volatile_trigger)
    end
  end

  property "delete_volatile_trigger/1 calls the `data_updater` server", context do
    %{realm_name: realm_name, device: device} = context

    check all trigger_id <- binary() do
      expected_signal =
        {:delete_volatile_trigger, trigger_id}

      Impl
      |> expect(:handle_signal, fn ^expected_signal, state -> {:ok, state} end)

      assert :ok =
               Core.delete_volatile_trigger(%{
                 realm_name: realm_name,
                 device_id: device.encoded_id,
                 trigger_id: trigger_id
               })
    end
  end

  test "start_device_deletion/3 calls the `data_updater` server", context do
    %{realm_name: realm_name, device: device} = context
    encoded_device_id = device.encoded_id
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond) |> Kernel.*(10)
    expected_signal = {:start_device_deletion, timestamp}

    Impl
    |> expect(:handle_signal, fn ^expected_signal, state -> {:ok, state} end)

    assert :ok = Core.start_device_deletion(realm_name, encoded_device_id, timestamp)
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
