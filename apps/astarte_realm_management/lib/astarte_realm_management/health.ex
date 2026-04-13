#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.RealmManagement.Health do
  @moduledoc """
  Performs health checks of the Realm Management service
  """

  alias Astarte.DataAccess.Health, as: DatabaseHealth
  alias Astarte.RealmManagement.Health

  @doc """
  Gets the backend health, and raises if it's not healthy.
  """
  def rpc_healthcheck do
    case Health.get_health() do
      :ready -> :ok
      :degraded -> :ok
      other -> raise RuntimeError, to_string(other)
    end
  end

  @doc """
  Gets the backend health.
  """
  def get_health do
    DatabaseHealth.get_health()
  end
end
