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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.InterfaceTest do
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataAccess.Realms.Interface, as: InterfaceData
  alias Astarte.DataAccess.Mappings
  alias Astarte.Core.Interface
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  use Astarte.Cases.Data
  use Astarte.Cases.Device
  use ExUnitProperties

  import Ecto.Query

  @interface_lifespan_decimicroseconds 60 * 10 * 1000 * 10000

  describe "Interface" do
    test "maybe_handle_cache_miss/3 updates device state on miss", context do
      %{
        realm_name: realm_name,
        astarte_instance_id: astarte_instance_id,
        interfaces: interfaces,
        device: device
      } = context

      keyspace = Realm.keyspace_name(realm_name)

      state = setup_state(realm_name, astarte_instance_id, device)
      %{last_seen_message: last_seen_message} = state

      interface = Enum.random(interfaces)

      %Interface{
        name: interface_name,
        major_version: interface_major
      } = interface

      query =
        from InterfaceData,
          where: [name: ^interface_name],
          select: [:interface_id]

      {:ok, interface} = Repo.fetch_one(query, prefix: keyspace)
      interface_id = interface.interface_id

      # Cache miss, the interface descriptor is nil
      {:ok, descriptor, new_state} =
        Core.Interface.maybe_handle_cache_miss(nil, interface_name, state)

      expiry = last_seen_message + @interface_lifespan_decimicroseconds

      {:ok, mappings} = Mappings.fetch_interface_mappings(realm_name, interface_id)
      mappings_map = Map.new(mappings, &{&1.endpoint_id, &1})

      assert %InterfaceDescriptor{
               name: ^interface_name,
               major_version: ^interface_major
             } = descriptor

      assert %{^interface_name => ^descriptor} = new_state.interfaces
      assert %{^interface_id => ^interface_name} = new_state.interface_ids_to_name

      assert {expiry, interface_name} in new_state.interfaces_by_expiry

      assert new_state.mappings
             |> Map.delete(nil)
             |> Map.equal?(mappings_map)
    end
  end

  def setup_state(realm, astarte_instance_id, device) do
    {:ok, message_tracker} = DataUpdater.fetch_message_tracker(realm, device.encoded_id)

    {:ok, data_updater} =
      DataUpdater.fetch_data_updater_process(realm, device.encoded_id, message_tracker, true)

    Astarte.DataAccess.Config
    |> Mimic.allow(self(), data_updater)
    |> Mimic.stub(:astarte_instance_id, fn -> {:ok, astarte_instance_id} end)
    |> Mimic.stub(:astarte_instance_id!, fn -> astarte_instance_id end)

    :ok = GenServer.call(data_updater, :start)

    DataUpdater.dump_state(realm, device.encoded_id)
  end

  def path_from_endpoint(prefix) do
    prefix
    |> String.split("/")
    |> Enum.map(fn token ->
      case Astarte.Core.Mapping.is_placeholder?(token) do
        true -> string(:alphanumeric, min_length: 1)
        false -> constant(token)
      end
    end)
    |> fixed_list()
    |> map(&Enum.join(&1, "/"))
  end

  def gen_tracking_id() do
    message_id = :erlang.unique_integer([:monotonic]) |> Integer.to_string()
    delivery_tag = {:injected_msg, make_ref()}
    {message_id, delivery_tag}
  end
end
