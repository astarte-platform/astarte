# Copyright 2017-2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

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

defmodule Astarte.AppEngine.APIWeb.GroupsView do
  use Astarte.AppEngine.APIWeb, :view

  def render("index.json", %{groups: groups}) do
    %{
      data: groups
    }
  end

  def render("create.json", %{group: group}) do
    %{
      data: %{
        group_name: group.group_name,
        devices: group.devices
      }
    }
  end

  def render("show.json", %{group: group}) do
    %{
      data: %{
        group_name: group.group_name
      }
    }
  end

  def render("devices_index.json", %{devices: devices}) do
    %{
      data: devices
    }
  end
end
