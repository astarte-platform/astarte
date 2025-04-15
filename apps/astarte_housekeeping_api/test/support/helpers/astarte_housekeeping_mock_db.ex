#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Housekeeping.Mock.DB do
  alias Astarte.Housekeeping.API.Realms.Realm

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put_realm(realm = %Realm{realm_name: realm_name}) do
    Agent.update(__MODULE__, &Map.put(&1, realm_name, realm))
  end

  def get_realm(realm_name) do
    Agent.get(__MODULE__, &Map.get(&1, realm_name))
  end

  def delete_realm(realm_name) do
    Agent.update(__MODULE__, &Map.delete(&1, realm_name))
  end

  def realm_exists?(realm_name) do
    Agent.get(__MODULE__, &Map.has_key?(&1, realm_name))
  end

  def realms_list do
    Agent.get(__MODULE__, &Map.keys(&1))
  end

  def set_health_status(status) do
    Agent.update(__MODULE__, &Map.put(&1, :health_status, status))
  end

  def get_health_status do
    Agent.get(__MODULE__, &Map.get(&1, :health_status, :READY))
  end

  def clean do
    Agent.update(__MODULE__, fn _x -> %{} end)
  end
end
