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

defmodule Astarte.RPC.Config.AstarteServices do
  @moduledoc """
  The clustering strategy that the node should use to discover other nodes.
  """

  use Skogsra.Type

  @all_services [
    :astarte_data_updater_plant,
    :astarte_pairing,
    :astarte_realm_management,
    :astarte_vmq_plugin
  ]
  @all_services_mapset MapSet.new(@all_services)

  @impl Skogsra.Type
  def cast(services) do
    services_mapset = MapSet.new(services)

    case MapSet.subset?(services_mapset, @all_services_mapset) do
      true -> {:ok, MapSet.to_list(services_mapset)}
      false -> :error
    end
  end
end
