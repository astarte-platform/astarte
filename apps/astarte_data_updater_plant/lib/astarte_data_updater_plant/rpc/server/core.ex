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

defmodule Astarte.DataUpdaterPlant.RPC.Server.Core do
  @moduledoc """
  The core logic handling the DataUpdaterPlant.RPC.Server
  """
  require Logger
  alias Astarte.DataUpdaterPlant.DataUpdater

  def install_volatile_trigger(volatile_trigger) do
    %{
      realm_name: realm,
      device_id: device_id,
      object_id: object_id,
      object_type: object_type,
      parent_id: parent_id,
      simple_trigger_id: trigger_id,
      simple_trigger: simple_trigger,
      trigger_target: trigger_target
    } = volatile_trigger

    DataUpdater.with_dup_and_message_tracker(
      realm,
      device_id,
      fn dup, _message_tracker ->
        GenServer.call(
          dup,
          {:handle_install_volatile_trigger, object_id, object_type, parent_id, trigger_id,
           simple_trigger, trigger_target}
        )
      end
    )
  end

  def delete_volatile_trigger(delete_request) do
    %{
      realm_name: realm,
      device_id: device_id,
      trigger_id: trigger_id
    } = delete_request

    DataUpdater.with_dup_and_message_tracker(
      realm,
      device_id,
      fn dup, _message_tracker ->
        GenServer.call(
          dup,
          {:handle_delete_volatile_trigger, trigger_id}
        )
      end
    )
  end
end
