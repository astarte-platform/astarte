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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.InternalHandler do
  @moduledoc """
  The `internal` message type handler for Astarte Data Updater.
  """
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.DataUpdater.State

  require Logger

  def handle_internal(state, "/heartbeat", _payload, message_id, timestamp) do
    {:continue, Impl.handle_heartbeat(state, message_id, timestamp)}
  end

  def handle_internal(%State{discard_messages: true} = state, "/f", _, message_id, _) do
    :ok = Queries.ack_end_device_deletion(state.realm, state.device_id)
    _ = Logger.info("End device deletion acked.", tag: "device_delete_ack")
    MessageTracker.ack_delivery(state.message_tracker, message_id)
    {:stop, state}
  end

  def handle_internal(state, path, payload, message_id, timestamp) do
    Logger.warning(
      "Unexpected internal message on #{path}, base64-encoded payload: #{inspect(Base.encode64(payload))}",
      tag: "unexpected_internal_message"
    )

    {:ok, new_state} = Core.Device.ask_clean_session(state, timestamp)
    MessageTracker.discard(new_state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :discarded_internal_message],
      %{},
      %{realm: new_state.realm}
    )

    base64_payload = Base.encode64(payload)

    error_metadata = %{
      "path" => inspect(path),
      "base64_payload" => base64_payload
    }

    # TODO maybe we don't want triggers on unexpected internal messages?
    Core.Trigger.execute_device_error_triggers(
      new_state,
      "unexpected_internal_message",
      error_metadata,
      timestamp
    )

    {:continue, Core.DataHandler.update_stats(new_state, "", nil, path, payload)}
  end
end
