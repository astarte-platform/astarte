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

defmodule Astarte.RPC.RealmManagementTest do
  use Astarte.RPC.Cases.RPCServer, async: true
  use Mneme

  import Astarte.Core.Generators.Device
  import Astarte.Core.Generators.Realm

  alias Astarte.RPC.RealmManagement
  alias Astarte.RPC.RealmManagement.DeviceDeletion

  test "server_name/0 returns the server name" do
    auto_assert {:via, Horde.Registry, {Astarte.RPC.RealmManagement.Registry, :server}} <-
                  RealmManagement.server_name()
  end

  test "init/1 returns the supervisor init spec" do
    auto_assert {:ok,
                 {%{auto_shutdown: :never, intensity: 3, period: 5, strategy: :rest_for_one},
                  [
                    %{
                      id: Astarte.RPC.RealmManagement.Registry,
                      start:
                        {Horde.Registry, :start_link,
                         [
                           [
                             keys: :unique,
                             name: Astarte.RPC.RealmManagement.Registry,
                             members: :auto
                           ]
                         ]},
                      type: :supervisor
                    }
                  ]}} <- RealmManagement.init(_ignored = nil)
  end

  describe "delete_device/2" do
    test "calls the rpc" do
      realm_name = realm_name() |> Enum.at(0)
      encoded_device_id = device_encoded_id() |> Enum.at(0)
      RealmManagement.delete_device(realm_name, encoded_device_id)

      assert_receive {:call, :realm_management,
                      %DeviceDeletion{
                        encoded_device_id: ^encoded_device_id,
                        realm_name: ^realm_name
                      }}
    end
  end
end
