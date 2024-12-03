# Copyright 2017-2019 SECO Mind Srl
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
