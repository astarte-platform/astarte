#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.RPC.DataUpdaterPlant do
  @moduledoc """
  This module sends RPC to DataUpdaterPlant
  """

  require Logger

  alias Astarte.AppEngine.API.RPC.DataUpdaterPlant.VolatileTrigger

  @rpc_behaviour Application.compile_env(
                   :astarte_appengine_api,
                   :data_updater_plant_rpc_client,
                   Astarte.AppEngine.API.RPC.DataUpdaterPlant.Client
                 )

  def install_volatile_trigger(realm_name, device_id, %VolatileTrigger{} = volatile_trigger) do
    %VolatileTrigger{
      object_id: object_id,
      object_type: object_type,
      serialized_simple_trigger: serialized_simple_trigger,
      parent_id: parent_id,
      simple_trigger_id: simple_trigger_id,
      serialized_trigger_target: serialized_trigger_target
    } = volatile_trigger

    volatile_trigger = %{
      realm_name: realm_name,
      device_id: device_id,
      object_id: object_id,
      object_type: object_type,
      parent_id: parent_id,
      simple_trigger: serialized_simple_trigger,
      simple_trigger_id: simple_trigger_id,
      trigger_target: serialized_trigger_target
    }

    @rpc_behaviour.install_volatile_trigger(volatile_trigger)
  end

  def delete_volatile_trigger(realm_name, device_id, trigger_id) do
    delete_trigger = %{
      realm_name: realm_name,
      device_id: device_id,
      trigger_id: trigger_id
    }

    @rpc_behaviour.delete_volatile_trigger(delete_trigger)
  end
end
