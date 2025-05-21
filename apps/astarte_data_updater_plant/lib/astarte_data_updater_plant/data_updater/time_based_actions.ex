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

defmodule Astarte.DataUpdaterPlant.TimeBasedActions do
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries

  @groups_lifespan_decimicroseconds 60 * 10 * 1000 * 10000

  def reload_groups_on_expiry(state, timestamp) do
    if state.last_groups_refresh + @groups_lifespan_decimicroseconds <= timestamp do
      # TODO this could be a bang!
      {:ok, groups} = Queries.get_device_groups(state.realm, state.device_id)

      %{state | last_groups_refresh: timestamp, groups: groups}
    else
      state
    end
  end
end
