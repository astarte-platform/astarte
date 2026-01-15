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

defmodule Astarte.RPC.Triggers.Core do
  alias Astarte.DataAccess.Interface
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Events.Triggers.Core, as: EventsCore
  alias Astarte.Core.CQLUtils

  @spec find_trigger_data(
          String.t(),
          TaggedSimpleTrigger.t(),
          EventsCore.fetch_triggers_data() | nil
        ) ::
          {:ok, EventsCore.fetch_triggers_data()} | {:error, :interface_not_found}
  def find_trigger_data(realm_name, tagged_simple_trigger, data) do
    simple_trigger = tagged_simple_trigger.simple_trigger_container.simple_trigger

    case {data, simple_trigger} do
      {_, {:device_trigger, _}} ->
        {:ok, %{}}

      {_, {:data_trigger, %{interface_name: "*"}}} ->
        {:ok, %{}}

      {_, {:data_trigger, %{match_path: "/*"}}} ->
        {:ok, %{}}

      {data, {:data_trigger, %{interface_name: name, interface_major: major}}} ->
        maybe_load_interface(realm_name, name, major, data)
    end
  end

  defp maybe_load_interface(realm_name, interface_name, interface_major, data) do
    interface_id = CQLUtils.interface_id(interface_name, interface_major)

    case data do
      %{interface_ids_to_name: %{^interface_id => _}} -> {:ok, data}
      _ -> load_interface(realm_name, interface_name, interface_major)
    end
  end

  @spec load_interface(String.t(), String.t(), non_neg_integer()) ::
          {:ok, %{interface_ids_to_name: map(), interfaces: map()}}
          | {:error, :interface_not_found}
  defp load_interface(realm_name, interface_name, interface_major) do
    with {:ok, descriptor} <-
           Interface.fetch_interface_descriptor(realm_name, interface_name, interface_major) do
      result = %{
        interface_ids_to_name: %{descriptor.interface_id => descriptor.name},
        interfaces: %{descriptor.name => descriptor}
      }

      {:ok, result}
    end
  end
end
