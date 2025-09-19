#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.StatsView do
  use Astarte.AppEngine.APIWeb, :view

  alias Astarte.AppEngine.APIWeb.StatsView

  def render("show_devices_stats.json", %{devices_stats: devices_stats}) do
    %{data: render_one(devices_stats, StatsView, "devices_stats.json", as: :devices_stats)}
  end

  def render("devices_stats.json", %{devices_stats: devices_stats}) do
    %{
      total_devices: devices_stats.total_devices,
      connected_devices: devices_stats.connected_devices
    }
  end
end
