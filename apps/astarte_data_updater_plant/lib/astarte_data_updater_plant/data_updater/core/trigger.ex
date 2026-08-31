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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.Trigger do
  @moduledoc """
  Core part of the data_updater message processing.

  This module contains functions and utilities to process triggers.
  """
  alias Astarte.DataUpdaterPlant.TriggersHandler

  def execute_pre_change_triggers(context) do
    %{value: value, previous_value: previous_value} = context
    old_bson_value = Cyanide.encode!(%{v: previous_value})
    payload = Cyanide.encode!(%{v: value})

    if previous_value != value do
      TriggersHandler.value_change(
        context,
        old_bson_value,
        payload
      )
    end

    :ok
  end

  def execute_post_change_triggers(context) do
    %{value: value, previous_value: previous_value} = context
    old_bson_value = Cyanide.encode!(%{v: previous_value})
    payload = Cyanide.encode!(%{v: value})

    case {previous_value, value} do
      {value, value} ->
        :ok

      {nil, _value} ->
        TriggersHandler.path_created(context, payload)

      {_previous_value, nil} ->
        TriggersHandler.path_removed(context)

      {_previous_value, _value} ->
        TriggersHandler.value_change_applied(context, old_bson_value, payload)
    end
  end

  def execute_device_error_triggers(state, error_name, error_metadata \\ %{}, timestamp) do
    timestamp_ms = div(timestamp, 10_000)

    TriggersHandler.device_error(
      state.realm,
      state.device_id,
      state.groups,
      error_name,
      error_metadata,
      timestamp_ms
    )

    :ok
  end
end
