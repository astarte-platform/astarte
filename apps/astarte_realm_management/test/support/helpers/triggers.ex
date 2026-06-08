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

defmodule Astarte.Helpers.Triggers do
  @moduledoc false
  alias Astarte.Events.Triggers.Cache
  alias Astarte.Events.TriggersHandler
  alias Astarte.RealmManagement.Triggers

  def reset_cache(realm_name) do
    Cache.reset_realm_cache(realm_name)
  end

  def rpc_trigger_client do
    Astarte.RealmManagement.Supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(fn {id, pid, _type, _mod} ->
      id == Astarte.RPC.Triggers.Client && pid
    end)
  end

  def register_device_deletion_started_trigger(realm_name, conditions) do
    register_device_trigger(
      realm_name,
      "device_deletion_started",
      :device_deletion_started_event,
      conditions
    )
  end

  def register_device_deletion_finished_trigger(realm_name, conditions) do
    register_device_trigger(
      realm_name,
      "device_deletion_finished",
      :device_deletion_finished_event,
      conditions
    )
  end

  defp register_device_trigger(realm_name, on_condition, event_type, conditions) do
    trigger_params = %{
      "action" => %{"http_post_url" => "http://astarte-platform.org"},
      "name" => "deletion_started_#{System.unique_integer([:positive])}",
      "simple_triggers" =>
        for {condition_type, condition_value} <- conditions do
          %{
            to_string(condition_type) => condition_value,
            "type" => "device_trigger",
            "on" => on_condition
          }
        end
    }

    Triggers.create_trigger(realm_name, trigger_params)

    test_process = self()
    ref = {:device_trigger_received, System.unique_integer()}

    Mimic.stub(TriggersHandler, :dispatch_event, fn _event,
                                                    ^event_type,
                                                    _target,
                                                    ^realm_name,
                                                    _device_id,
                                                    _timpestamp,
                                                    _policy ->
      send(test_process, ref)
    end)

    ref
  end
end
