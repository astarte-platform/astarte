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
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.DataUpdater.State

  require Logger

  def handle_internal(state, "/heartbeat", _payload, timestamp) do
    Core.HeartbeatHandler.handle_heartbeat(state, timestamp)
  end

  def handle_internal(%State{discard_messages: true} = state, "/f", _, _) do
    :ok = Queries.ack_end_device_deletion(state.realm, state.device_id)
    _ = Logger.info("End device deletion acked.", tag: "device_delete_ack")

    {:stop, :ack_end_device_deletion, :ack, state}
  end

  def handle_internal(state, path, payload, timestamp) do
    context = %{
      state: state,
      path: path,
      payload: payload,
      timestamp: timestamp,
      interface: ""
    }

    error = %{
      message:
        "Unexpected internal message on #{path}, base64-encoded payload: #{inspect(Base.encode64(payload))}",
      error: :unexpected_internal_message,
      logger_metadata: [tag: "unexpected_internal_message"],
      error_name: "unexpected_internal_message"
    }

    Core.Error.handle_error(context, error)
  end
end
