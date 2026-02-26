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
  @moduledoc """
  This module is responsible for handling introspection messages.
  """
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.State

  require Logger

  def handle_introspection(%State{discard_messages: true} = state, _, _) do
    {:ack, :discard_messages, state}
  end

  def handle_introspection(state, payload, timestamp) do
    case PayloadsDecoder.parse_introspection(payload) do
      {:ok, new_introspection_list} ->
        Core.Device.process_introspection(
          state,
          new_introspection_list,
          payload,
          timestamp
        )

      {:error, :invalid_introspection} ->
        context = %{
          state: state,
          payload: payload,
          timestamp: timestamp
        }

        error = %{
          message: "Discarding invalid introspection: #{inspect(Base.encode64(payload))}.",
          logger_metadata: [tag: "invalid_introspection"],
          error_name: "invalid_introspection",
          error: :invalid_introspection,
          telemetry_name: [:astarte, :data_updater_plant, :data_updater, :discarded_introspection]
        }

        Core.Error.handle_error(context, error)
    end
  end
end
