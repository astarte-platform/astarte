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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.CapabilitiesHandler do
  @moduledoc """
  This module handles the capabilities of the data updater, such as purge properties compression format.
  """
  alias Astarte.Core.Device.Capabilities
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.Error
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.DataUpdater.State

  require Logger

  @doc """
  Handles the capabilities message from a device.
  It updates the device's capabilities in the database and returns the updated state.

  ## Parameters
  - `state`: The current state of the data updater.
  - `payload`: The binary payload containing the capabilities data.
  - `message_id`: The ID of the message being processed.
  - `timestamp`: The timestamp of the message.

  ## Returns
  - state: The updated state of the data updater after processing the capabilities message.
  """
  @spec handle_capabilities(
          state :: State.t(),
          payload :: binary(),
          message_id :: binary(),
          timestamp :: integer()
        ) :: State.t()
  def handle_capabilities(state, payload, message_id, timestamp) do
    %State{device_id: device_id, realm: realm} = state

    case parse_capabilities(payload, state) do
      {:ok, capabilities} ->
        Queries.set_device_capabilities(realm, device_id, capabilities)

        %State{state | capabilities: capabilities}

      {:error, error} ->
        handle_error(state, error, payload, message_id, timestamp)
    end
  end

  defp handle_error(state, error, payload, message_id, timestamp) do
    error = %{
      message:
        "Unexpected error while processing payload #{inspect(Base.encode64(payload))}: #{error}",
      logger_metadata: [tag: "malformed_capabilities_message"],
      error_name: "malformed_capabilities_message"
    }

    context = %{
      state: state,
      payload: payload,
      message_id: message_id,
      timestamp: timestamp
    }

    Error.handle_error(context, error, update_stats: false)
  end

  defp parse_capabilities(payload, state) do
    with {:ok, payload} <- Cyanide.decode(payload) do
      Capabilities.changeset(state.capabilities, payload)
      |> Ecto.Changeset.apply_action(:update)
    end
  end
end
