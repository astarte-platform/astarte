#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.Pairing.APIWeb.DeviceInfoView do
  use Astarte.Pairing.APIWeb, :view
  alias Astarte.Pairing.APIWeb.DeviceInfoView

  def render("show.json", %{device_info: device_info}) do
    %{data: render_one(device_info, DeviceInfoView, "device_info.json")}
  end

  def render("device_info.json", %{device_info: device_info}) do
    %{version: device_info.version, status: device_info.status, protocols: device_info.protocols}
  end
end
