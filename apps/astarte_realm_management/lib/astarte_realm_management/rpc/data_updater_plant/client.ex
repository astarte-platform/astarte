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

defmodule Astarte.RealmManagement.RPC.DataUpdaterPlant.Client do
  alias Astarte.Core.Device

  def start_device_deletion_rpc(realm_name, decoded_id) do
    encoded_device_id = Device.encode_device_id(decoded_id)

    server_via_tuple()
    |> GenServer.call({:start_device_deletion, {realm_name, encoded_device_id}})
  end

  def install_trigger(realm_name, tagged_simple_trigger, target, policy) do
    server_via_tuple()
    |> GenServer.cast({:install_trigger, {realm_name, tagged_simple_trigger, target, policy}})
  end

  defp server_via_tuple(), do: {:via, Horde.Registry, {Registry.DataUpdaterRPC, :server}}
end
