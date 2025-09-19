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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.IntrospectionHandler do
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater.State

  require Logger

  def handle_introspection(%State{discard_messages: true} = state, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_introspection(state, payload, message_id, timestamp) do
    with {:ok, new_introspection_list} <- PayloadsDecoder.parse_introspection(payload) do
      Core.Device.process_introspection(
        state,
        new_introspection_list,
        payload,
        message_id,
        timestamp
      )
    else
      {:error, :invalid_introspection} ->
        Logger.warning("Discarding invalid introspection: #{inspect(Base.encode64(payload))}.",
          tag: "invalid_introspection"
        )

        {:ok, new_state} = Core.Device.ask_clean_session(state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_introspection],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "base64_payload" => base64_payload
        }

        Core.Trigger.execute_device_error_triggers(
          new_state,
          "invalid_introspection",
          error_metadata,
          timestamp
        )

        Core.DataHandler.update_stats(new_state, "", nil, "", payload)
    end
  end
end
