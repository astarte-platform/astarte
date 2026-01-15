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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.Error do
  @moduledoc """
  Part of the `DataUpdater` `Core` modules

  This module is responsible for providing utilities to handle errors during the handling of messages
  """
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  require Logger

  @doc """
  Handles errors arising when handling data from a device. It needs a context,
  a map in the shape:

  %{
    state: DataUpdater.State.t(),
    interface: optional(Astarte.Core.Interface.t()),
    path: optional(String.t()),
    message_id: binary(),
    timestamp: DateTime.t(),
    payload: binary()
  }

  and returns the updated state after asking for a clean session

  the `error` should consist of a map with

  %{
    message: String.t(),
    tag: String.t(),
    error_name: String.t(),
  }

  The first two for the logging and the latter to execute device error triggers.
  The optional `update_stats` parameter switches the update of stats when the
  telemetry has been executed.

  An optional option keyword list can be supplied, to specify the handle_error behavior:
  - update_stats: updates message stats in the %State{}
  - ask_clean_session: forcefully disconnects the device and creates a clean session
  - execute_error_triggers: execute device error triggers
  """
  def handle_error(context, error, opts \\ []) do
    %{
      state: state,
      message_id: message_id,
      timestamp: timestamp,
      payload: payload
    } = context

    interface = Map.get(context, :interface, "")
    path = Map.get(context, :path, "")

    %{
      message: message,
      logger_metadata: logger_metadata,
      error_name: error_name
    } = error

    update_stats = Keyword.get(opts, :update_stats, true)
    ask_clean_session = Keyword.get(opts, :ask_clean_session, true)
    execute_error_triggers = Keyword.get(opts, :execute_error_triggers, true)

    Logger.warning(message, logger_metadata)

    {:ok, state} =
      case ask_clean_session do
        true -> Core.Device.ask_clean_session(state, timestamp)
        false -> {:ok, state}
      end

    MessageTracker.discard(state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :discarded_message],
      %{},
      %{realm: state.realm}
    )

    base64_payload = Base.encode64(payload)

    error_metadata = %{
      "interface" => inspect(interface),
      "path" => inspect(path),
      "base64_payload" => base64_payload
    }

    if execute_error_triggers,
      do:
        Core.Trigger.execute_device_error_triggers(
          state,
          error_name,
          error_metadata,
          timestamp
        )

    if update_stats,
      do: Core.DataHandler.update_stats(state, interface, nil, path, payload),
      else: state
  end
end
