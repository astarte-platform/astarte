#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

  def start_link(agent_name \\ __MODULE__) do
    Agent.start_link(fn -> %{} end, name: agent_name)
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

  def put_realm(realm = %Realm{realm_name: realm_name}) do
    cond do
      realm_exists?(realm_name) ->
        {:error, :existing_realm}

      true ->
        Agent.update(current_agent(), &Map.put(&1, realm_name, realm))
    end
  end

  def get_realm(realm_name) do
    Agent.get(current_agent(), &Map.get(&1, realm_name))
  end

  def delete_realm(realm_name) do
    cond do
      !realm_exists?(realm_name) ->
        {:error, :realm_not_found}

      realm_deletion_disabled?() ->
        {:error, :realm_deletion_disabled}

      true ->
        Agent.update(current_agent(), &Map.delete(&1, realm_name))
    end
  end

  def realm_exists?(realm_name) do
    Agent.get(current_agent(), &Map.has_key?(&1, realm_name))
  end

  def realms_list do
    Agent.get(current_agent(), &Map.keys(&1))
  end

  def set_health_status(status) do
    Agent.update(current_agent(), &Map.put(&1, :health_status, status))
  end

  def get_health_status do
    Agent.get(current_agent(), &Map.get(&1, :health_status, :READY))
  end

  def set_realm_deletion_status(status) when is_boolean(status) do
    Agent.update(current_agent(), &Map.put(&1, :realm_deletion_disabled, !status))
  end

  defp realm_deletion_disabled? do
    Agent.get(current_agent(), &Map.get(&1, :realm_deletion_disabled, false))
  end

  defp current_agent do
    Process.get(:current_agent, __MODULE__)
  end
end
