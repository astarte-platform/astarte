#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.StatsController do
  use Astarte.AppEngine.APIWeb, :controller

  alias Astarte.AppEngine.API.Stats
  alias Astarte.AppEngine.API.Stats.DevicesStats

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def show_devices_stats(conn, %{"realm_name" => realm_name}) do
    with {:ok, %DevicesStats{} = devices_stats} <- Stats.get_devices_stats(realm_name) do
      render(conn, "show_devices_stats.json", %{devices_stats: devices_stats})
    end
  end
end
