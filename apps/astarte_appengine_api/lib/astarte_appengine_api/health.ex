#
# This file is part of Astarte.
#
# Copyright 2019-2025 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.Health do
  alias Astarte.AppEngine.API.Queries

  require Logger

  def get_health do
    case Queries.check_astarte_health(:quorum) do
      :ok ->
        :ok

      {:error, :database_connection_error} ->
        {:error, :bad_health}

      {:error, :health_check_bad} ->
        case Queries.check_astarte_health(:one) do
          :ok -> {:error, :degraded_health}
          _error -> {:error, :bad_health}
        end
    end
  end
end
