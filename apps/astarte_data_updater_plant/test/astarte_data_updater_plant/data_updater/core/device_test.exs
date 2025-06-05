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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.DeviceTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Mimic

  import Astarte.Helpers.DataUpdater

  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin
  alias Astarte.DataAccess.Devices.Device, as: DatabaseDevice
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Helpers.Database

  @timestamp_us_x_10 Database.make_timestamp("2025-05-14T14:00:32+00:00")

  setup_all %{realm_name: realm_name, device: device} do
    setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state}
  end

  describe "ask_clean_session/2" do
    test "disconnects device and clears cache on successful disconnect", %{
      realm_name: realm_name,
      state: state
    } do
      # Successfully disconnected
      Mimic.expect(VMQPlugin, :disconnect, fn _client_id, _discard_state -> :ok end)

      {:ok, new_state} = Core.Device.ask_clean_session(state, @timestamp_us_x_10)

      assert read_device_empty_cache(realm_name, state.device_id) == true
      assert new_state.connected == false
    end

    test "clears cache and marks device disconnected if already disconnected", %{
      realm_name: realm_name,
      state: state
    } do
      # Not found means it was already disconnected, succeed anyway
      Mimic.expect(VMQPlugin, :disconnect, fn _client_id, _discard_state ->
        {:error, :not_found}
      end)

      {:ok, new_state} = Core.Device.ask_clean_session(state, @timestamp_us_x_10)

      assert read_device_empty_cache(realm_name, state.device_id) == true
      assert new_state.connected == false
    end

    test "returns error and clears cache on disconnect failure", %{
      realm_name: realm_name,
      state: state
    } do
      # Some other error, return it
      Mimic.expect(VMQPlugin, :disconnect, fn _client_id, _discard_state ->
        {:error, :timeout}
      end)

      assert {:error, :clean_session_failed} =
               Core.Device.ask_clean_session(state, @timestamp_us_x_10)

      assert read_device_empty_cache(realm_name, state.device_id) == true
    end
  end

  defp read_device_empty_cache(realm_name, device_id) do
    Repo.get!(DatabaseDevice, device_id, prefix: Realm.keyspace_name(realm_name))
    |> Map.fetch!(:pending_empty_cache)
  end
end
