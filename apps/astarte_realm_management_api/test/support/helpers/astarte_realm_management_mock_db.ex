#
# This file is part of Astarte.
#
# Copyright 2021 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.Helpers.RPCMock.DB do
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger

  def start_link(agent_name \\ __MODULE__) do
    Agent.start_link(
      fn -> %{interfaces: %{}, trigger_policies: %{}, devices: %{}, triggers: %{}} end,
      name: agent_name
    )
  end

  def child_spec(name) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [name]},
      type: :worker,
      restart: :temporary,
      shutdown: 500
    }
  end

  defp current_agent do
    Process.get(:current_agent, __MODULE__)
  end

  def clean() do
    Agent.update(current_agent(), fn state ->
      state
      |> Map.put(:interfaces, %{})
      |> Map.put(:trigger_policies, %{})
      |> Map.put(:devices, %{})
      |> Map.put(:triggers, %{})
    end)
  end

  def delete_interface(realm, name, major) do
    cond do
      major != 0 ->
        {:error, :forbidden}

      get_interface(realm, name, major) |> is_nil() ->
        {:error, :interface_not_found}

      true ->
        Agent.update(current_agent(), fn %{interfaces: interfaces} = state ->
          %{state | interfaces: Map.delete(interfaces, {realm, name, major})}
        end)
    end
  end

  def get_interfaces_list(realm) do
    Agent.get(current_agent(), fn %{interfaces: interfaces} ->
      keys = Map.keys(interfaces)

      for {^realm, name, _major} <- keys do
        name
      end
      |> Enum.uniq()
    end)
  end

  def get_interface_versions_list(realm, name) do
    Agent.get(current_agent(), fn %{interfaces: interfaces} ->
      keys = Map.keys(interfaces)

      majors =
        for {^realm, ^name, major} <- keys do
          major
        end

      for major <- majors do
        %Interface{minor_version: minor} = Map.get(interfaces, {realm, name, major})
        [major_version: major, minor_version: minor]
      end
    end)
  end

  def get_interface_source(realm, name, major) do
    if interface = get_interface(realm, name, major) do
      Jason.encode!(interface)
    else
      nil
    end
  end

  def get_interface(realm, name, major) do
    Agent.get(current_agent(), fn %{interfaces: interfaces} ->
      Map.get(interfaces, {realm, name, major})
    end)
  end

  def get_jwt_public_key_pem(realm) do
    Agent.get(current_agent(), &Map.get(&1, "jwt_public_key_pem_#{realm}"))
  end

  def get_device_registration_limit(realm) do
    Agent.get(current_agent(), &Map.get(&1, "device_registration_limit_#{realm}"))
  end

  def get_datastream_maximum_storage_retention(realm) do
    Agent.get(current_agent(), &Map.get(&1, "datastream_maximum_storage_retention_#{realm}"))
  end

  def install_interface(realm, %Interface{name: name, major_version: major} = interface) do
    with {:already_installed_interface, nil} <-
           {:already_installed_interface, get_interface(realm, name, major)},
         max_retention = get_datastream_maximum_storage_retention(realm),
         {:maximum_database_retention_exceeded, false} <-
           {:maximum_database_retention_exceeded,
            mappings_max_storage_retention_exceeded?(interface.mappings, max_retention)},
         normalized_name = normalize_interface_name(name),
         {:interface_name_collision, false} <-
           {:interface_name_collision,
            Enum.any?(get_interfaces_list(realm), fn existing_name ->
              name != existing_name and normalize_interface_name(existing_name) == normalized_name
            end)} do
      Agent.update(current_agent(), fn %{interfaces: interfaces} = state ->
        %{state | interfaces: Map.put(interfaces, {realm, name, major}, interface)}
      end)
    else
      {:already_installed_interface, %Interface{} = _} ->
        {:error, :already_installed_interface}

      {:maximum_database_retention_exceeded, true} ->
        {:error, :maximum_database_retention_exceeded}

      {:interface_name_collision, true} ->
        {:error, :interface_name_collision}
    end
  end

  defp normalize_interface_name(interface_name) do
    String.replace(interface_name, "-", "")
    |> String.downcase()
  end

  def update_interface(
        realm,
        %Interface{name: name, major_version: major, mappings: new_mappings} = interface
      ) do
    # Some basic error checking simulation
    with {:old_interface, old_interface} when not is_nil(old_interface) <-
           {:old_interface, get_interface(realm, name, major)},
         {:different_minor, true} <-
           {:different_minor, old_interface.minor_version != interface.minor_version},
         {:minor_bumped, true} <-
           {:minor_bumped, old_interface.minor_version < interface.minor_version},
         {:mappings_valid, :ok} <-
           {:mappings_valid, validate_mappings(old_interface.mappings, new_mappings)},
         :ok <- validate_descriptor_compatibility(old_interface, interface) do
      Agent.update(current_agent(), fn %{interfaces: interfaces} = state ->
        %{state | interfaces: Map.put(interfaces, {realm, name, major}, interface)}
      end)
    else
      {:old_interface, nil} ->
        {:error, :interface_major_version_does_not_exist}

      {:different_minor, false} ->
        {:error, :minor_version_not_increased}

      {:minor_bumped, false} ->
        {:error, :downgrade_not_allowed}

      {:mappings_valid, {:error, :missing_endpoints}} ->
        {:error, :missing_endpoints}

      {:mappings_valid, {:error, :incompatible_endpoint_change}} ->
        {:error, :incompatible_endpoint_change}

      {:error, :invalid_update} ->
        {:error, :invalid_update}
    end
  end

  defp validate_descriptor_compatibility(old_interface, new_interface) do
    if old_interface.type == new_interface.type and
         old_interface.ownership == new_interface.ownership do
      :ok
    else
      {:error, :invalid_update}
    end
  end

  defp validate_mappings(old_mappings, new_mappings) do
    old_mappings_map =
      Enum.into(old_mappings, %{}, fn mapping -> {mapping.endpoint_id, mapping} end)

    new_mappings_map =
      Enum.into(new_mappings, %{}, fn mapping -> {mapping.endpoint_id, mapping} end)

    Enum.reduce_while(old_mappings_map, :ok, fn {endpoint_id, old_mapping}, acc ->
      case Map.fetch(new_mappings_map, endpoint_id) do
        {:ok, new_mapping} ->
          if allowed_mapping_update?(old_mapping, new_mapping) do
            {:cont, acc}
          else
            {:halt, {:error, :incompatible_endpoint_change}}
          end

        :error ->
          {:halt, {:error, :missing_endpoints}}
      end
    end)
  end

  defp allowed_mapping_update?(old_mapping, new_mapping) do
    drop_mapping_negligible_fields(old_mapping) == drop_mapping_negligible_fields(new_mapping)
  end

  defp drop_mapping_negligible_fields(%Mapping{} = mapping) do
    %{
      mapping
      | doc: nil,
        description: nil,
        explicit_timestamp: false,
        retention: nil,
        expiry: nil
    }
  end

  def put_jwt_public_key_pem(realm, jwt_public_key_pem) do
    Agent.update(current_agent(), &Map.put(&1, "jwt_public_key_pem_#{realm}", jwt_public_key_pem))
  end

  def put_device_registration_limit(realm, limit) do
    Agent.update(current_agent(), &Map.put(&1, "device_registration_limit_#{realm}", limit))
  end

  def put_datastream_maximum_storage_retention(realm, retention) do
    Agent.update(
      current_agent(),
      &Map.put(&1, "datastream_maximum_storage_retention_#{realm}", retention)
    )
  end

  def install_trigger_policy(realm, %Policy{name: name} = policy) do
    if get_trigger_policy(realm, name) != nil do
      {:error, :trigger_policy_already_present}
    else
      Agent.update(current_agent(), fn %{trigger_policies: trigger_policies} = state ->
        %{state | trigger_policies: Map.put(trigger_policies, {realm, name}, policy)}
      end)
    end
  end

  def get_trigger_policies_list(realm) do
    Agent.get(current_agent(), fn %{trigger_policies: trigger_policies} ->
      keys = Map.keys(trigger_policies)

      for {^realm, name} <- keys do
        name
      end
      |> Enum.uniq()
    end)
  end

  def get_trigger_policy(realm, name) do
    Agent.get(current_agent(), fn %{trigger_policies: trigger_policies} ->
      Map.get(trigger_policies, {realm, name})
    end)
  end

  def delete_trigger_policy(realm, name) do
    if get_trigger_policy(realm, name) == nil do
      {:error, :trigger_policy_not_found}
    else
      Agent.update(current_agent(), fn %{interfaces: interfaces} = state ->
        %{state | trigger_policies: Map.delete(interfaces, {realm, name})}
      end)
    end
  end

  def get_trigger_policy_source(realm_name, name) do
    if trigger_policy = get_trigger_policy(realm_name, name) do
      Jason.encode!(trigger_policy)
    else
      nil
    end
  end

  def create_device(realm, device_id) do
    Agent.update(current_agent(), fn %{devices: devices} = state ->
      %{state | devices: Map.put(devices, {realm, device_id}, {realm, device_id})}
    end)
  end

  def get_device(realm, device_id) do
    Agent.get(current_agent(), fn %{devices: devices} ->
      Map.get(devices, {realm, device_id})
    end)
  end

  def delete_device(realm, device_id) do
    if get_device(realm, device_id) == nil do
      {:error, :device_not_found}
    else
      Agent.update(current_agent(), fn %{devices: devices} = state ->
        %{state | devices: Map.delete(devices, {realm, device_id})}
      end)
    end
  end

  defp mappings_max_storage_retention_exceeded?(_mappings, nil), do: false

  defp mappings_max_storage_retention_exceeded?(mappings, max_retention) do
    Enum.all?(mappings, fn %Mapping{database_retention_ttl: retention} ->
      retention != nil and retention > max_retention
    end)
  end

  def install_trigger(
        realm_name,
        trigger_name,
        policy_name,
        action,
        serialized_tagged_simple_triggers
      ) do
    if get_trigger(realm_name, trigger_name) do
      {:error, :already_installed_trigger}
    else
      tagged_simple_triggers =
        Enum.map(serialized_tagged_simple_triggers, &TaggedSimpleTrigger.decode/1)

      trigger = %{
        trigger_name: trigger_name,
        policy: policy_name,
        trigger_action: action,
        tagged_simple_triggers: tagged_simple_triggers
      }

      Agent.update(current_agent(), fn %{triggers: triggers} = state ->
        %{state | triggers: Map.put(triggers, {realm_name, trigger_name}, trigger)}
      end)
    end
  end

  def get_triggers_list(realm_name) do
    Agent.get(current_agent(), fn %{triggers: triggers} ->
      keys = Map.keys(triggers)

      for {^realm_name, trigger_name} <- keys do
        trigger_name
      end
      |> Enum.uniq()
    end)
  end

  def get_trigger(realm_name, trigger_name) do
    Agent.get(current_agent(), fn %{triggers: triggers} ->
      Map.get(triggers, {realm_name, trigger_name})
    end)
  end

  def delete_trigger(realm_name, trigger_name) do
    if get_trigger(realm_name, trigger_name) == nil do
      {:error, :trigger_not_found}
    else
      Agent.update(current_agent(), fn %{triggers: triggers} = state ->
        %{state | triggers: Map.delete(triggers, {realm_name, trigger_name})}
      end)
    end
  end
end
