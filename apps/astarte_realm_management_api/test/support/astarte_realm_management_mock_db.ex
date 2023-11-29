#
# This file is part of Astarte.
#
# Copyright 2021 - 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagement.Mock.DB do
  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.Policy

  def start_link do
    Agent.start_link(fn -> %{interfaces: %{}, trigger_policies: %{}, devices: %{}} end,
      name: __MODULE__
    )
  end

  def drop_interfaces() do
    Agent.update(__MODULE__, &Map.put(&1, :interfaces, %{}))
  end

  def delete_interface(realm, name, major) do
    if get_interface(realm, name, major) == nil do
      {:error, :interface_not_found}
    else
      Agent.update(__MODULE__, fn %{interfaces: interfaces} = state ->
        %{state | interfaces: Map.delete(interfaces, {realm, name, major})}
      end)
    end
  end

  def get_interfaces_list(realm) do
    Agent.get(__MODULE__, fn %{interfaces: interfaces} ->
      keys = Map.keys(interfaces)

      for {^realm, name, _major} <- keys do
        name
      end
      |> Enum.uniq()
    end)
  end

  def get_interface_versions_list(realm, name) do
    Agent.get(__MODULE__, fn %{interfaces: interfaces} ->
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
    Agent.get(__MODULE__, fn %{interfaces: interfaces} ->
      Map.get(interfaces, {realm, name, major})
    end)
  end

  def get_jwt_public_key_pem(realm) do
    Agent.get(__MODULE__, &Map.get(&1, "jwt_public_key_pem_#{realm}"))
  end

  def get_device_registration_limit(realm) do
    Agent.get(__MODULE__, &Map.get(&1, "device_registration_limit_#{realm}"))
  end

  def install_interface(realm, %Interface{name: name, major_version: major} = interface) do
    if get_interface(realm, name, major) != nil do
      {:error, :already_installed_interface}
    else
      Agent.update(__MODULE__, fn %{interfaces: interfaces} = state ->
        %{state | interfaces: Map.put(interfaces, {realm, name, major}, interface)}
      end)
    end
  end

  def update_interface(realm, %Interface{name: name, major_version: major} = interface) do
    # Some basic error checking simulation
    with {:old_interface, old_interface} when not is_nil(old_interface) <-
           {:old_interface, get_interface(realm, name, major)},
         {:different_minor, true} <-
           {:different_minor, old_interface.minor_version != interface.minor_version},
         {:minor_bumped, true} <-
           {:minor_bumped, old_interface.minor_version < interface.minor_version} do
      Agent.update(__MODULE__, fn %{interfaces: interfaces} = state ->
        %{state | interfaces: Map.put(interfaces, {realm, name, major}, interface)}
      end)
    else
      {:old_interface, nil} ->
        {:error, :interface_major_version_does_not_exist}

      {:different_minor, false} ->
        {:error, :minor_version_not_increased}

      {:minor_bumped, false} ->
        {:error, :downgrade_not_allowed}
    end
  end

  def put_jwt_public_key_pem(realm, jwt_public_key_pem) do
    Agent.update(__MODULE__, &Map.put(&1, "jwt_public_key_pem_#{realm}", jwt_public_key_pem))
  end

  def put_device_registration_limit(realm, limit) do
    Agent.update(__MODULE__, &Map.put(&1, "device_registration_limit_#{realm}", limit))
  end

  def install_trigger_policy(realm, %Policy{name: name} = policy) do
    if get_trigger_policy(realm, name) != nil do
      {:error, :trigger_policy_already_present}
    else
      Agent.update(__MODULE__, fn %{trigger_policies: trigger_policies} = state ->
        %{state | trigger_policies: Map.put(trigger_policies, {realm, name}, policy)}
      end)
    end
  end

  def get_trigger_policies_list(realm) do
    Agent.get(__MODULE__, fn %{trigger_policies: trigger_policies} ->
      keys = Map.keys(trigger_policies)

      for {^realm, name} <- keys do
        name
      end
      |> Enum.uniq()
    end)
  end

  def get_trigger_policy(realm, name) do
    Agent.get(__MODULE__, fn %{trigger_policies: trigger_policies} ->
      Map.get(trigger_policies, {realm, name})
    end)
  end

  def delete_trigger_policy(realm, name) do
    if get_trigger_policy(realm, name) == nil do
      {:error, :trigger_policy_not_found}
    else
      Agent.update(__MODULE__, fn %{interfaces: interfaces} = state ->
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
    Agent.update(__MODULE__, fn %{devices: devices} = state ->
      %{state | devices: Map.put(devices, {realm, device_id}, {realm, device_id})}
    end)
  end

  def get_device(realm, device_id) do
    Agent.get(__MODULE__, fn %{devices: devices} ->
      Map.get(devices, {realm, device_id})
    end)
  end

  def delete_device(realm, device_id) do
    if get_device(realm, device_id) == nil do
      {:error, :device_not_found}
    else
      Agent.update(__MODULE__, fn %{devices: devices} = state ->
        %{state | devices: Map.delete(devices, {realm, device_id})}
      end)
    end
  end
end
