# Copyright 2017-2020 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.TriggerEngine.Health do
  @moduledoc """
  Performs health checks of the Trigger Engine service.
  """

  alias Astarte.TriggerEngine.Health.Queries

  def get_health do
    case Queries.get_astarte_health(:quorum) do
      :ok ->
        {:ok, %{status: :ready}}

      {:error, :health_check_bad} ->
        case Queries.get_astarte_health(:one) do
          :ok ->
            {:ok, %{status: :degraded}}

          {:error, %{status: :health_check_bad}} ->
            {:ok, %{status: :bad}}

          {:error, :database_connection_error} ->
            {:ok, %{status: :error}}
        end

      {:error, :database_connection_error} ->
        {:ok, %{status: :error}}
    end
  end
end
