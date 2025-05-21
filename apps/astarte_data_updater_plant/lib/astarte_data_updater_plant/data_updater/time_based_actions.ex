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

defmodule Astarte.DataUpdaterPlant.TimeBasedActions do
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersProtobufUtils
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries

  @groups_lifespan_decimicroseconds 60 * 10 * 1000 * 10000
  @device_triggers_lifespan_decimicroseconds 60 * 10 * 1000 * 10000

  def reload_groups_on_expiry(state, timestamp) do
    if state.last_groups_refresh + @groups_lifespan_decimicroseconds <= timestamp do
      # TODO this could be a bang!
      {:ok, groups} = Queries.get_device_groups(state.realm, state.device_id)

      %{state | last_groups_refresh: timestamp, groups: groups}
    else
      state
    end
  end

  def purge_expired_interfaces(state, timestamp) do
    expired =
      Enum.take_while(state.interfaces_by_expiry, fn {expiry, _interface} ->
        expiry <= timestamp
      end)

    new_interfaces_by_expiry = Enum.drop(state.interfaces_by_expiry, length(expired))

    interfaces_to_drop_list =
      for {_exp, iface} <- expired do
        iface
      end

    state
    |> Core.Interface.forget_interfaces(interfaces_to_drop_list)
    |> Map.put(:interfaces_by_expiry, new_interfaces_by_expiry)
  end

  def reload_device_triggers_on_expiry(state, timestamp) do
    if state.last_device_triggers_refresh + @device_triggers_lifespan_decimicroseconds <=
         timestamp do
      any_device_id = SimpleTriggersProtobufUtils.any_device_object_id()

      any_interface_id = SimpleTriggersProtobufUtils.any_interface_object_id()

      device_and_any_interface_object_id =
        SimpleTriggersProtobufUtils.get_device_and_any_interface_object_id(state.device_id)

      # TODO when introspection triggers are supported, we should also forget any_interface
      # introspection triggers here, or handle them separately

      state
      |> Map.put(:last_device_triggers_refresh, timestamp)
      |> Map.put(:device_triggers, %{})
      |> forget_any_interface_data_triggers()
      |> Core.Trigger.populate_triggers_for_object!(any_device_id, :any_device)
      |> Core.Trigger.populate_triggers_for_object!(state.device_id, :device)
      |> Core.Trigger.populate_triggers_for_object!(any_interface_id, :any_interface)
      |> Core.Trigger.populate_triggers_for_object!(
        device_and_any_interface_object_id,
        :device_and_any_interface
      )
      |> populate_group_device_triggers!()
      |> populate_group_and_any_interface_triggers!()
    else
      state
    end
  end

  defp forget_any_interface_data_triggers(state) do
    updated_data_triggers =
      for {{_type, iface_id, _endpoint} = key, value} <- state.data_triggers,
          iface_id != :any_interface,
          into: %{} do
        {key, value}
      end

    %{state | data_triggers: updated_data_triggers}
  end

  defp populate_group_device_triggers!(state) do
    Enum.map(state.groups, &SimpleTriggersProtobufUtils.get_group_object_id/1)
    |> Enum.reduce(state, &Core.Trigger.populate_triggers_for_object!(&2, &1, :group))
  end

  defp populate_group_and_any_interface_triggers!(state) do
    Enum.map(state.groups, &SimpleTriggersProtobufUtils.get_group_and_any_interface_object_id/1)
    |> Enum.reduce(
      state,
      &Core.Trigger.populate_triggers_for_object!(&2, &1, :group_and_any_interface)
    )
  end
end
