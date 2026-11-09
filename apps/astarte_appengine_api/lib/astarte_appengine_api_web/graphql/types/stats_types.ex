#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.AppEngine.APIWeb.GraphQL.Types.StatsTypes do
  @moduledoc """
  GraphQL types for the device statistics.
  """

  use Absinthe.Schema.Notation

  @desc "Device count statistics of a realm"
  object :devices_stats do
    @desc "The number of devices registered in the realm"
    field :total_devices, non_null(:integer)

    @desc "The number of devices currently connected"
    field :connected_devices, non_null(:integer)
  end
end
