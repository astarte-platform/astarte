#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.Test.Setups.Device do
  use ExUnit.Case, async: false
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper
  alias Astarte.Test.Generators.Device, as: DeviceGenerator

  def init(%{device_count: device_count, interfaces: interfaces}) do
    {:ok, devices: DeviceGenerator.device(interfaces: interfaces) |> Enum.take(device_count)}
  end

  def setup(%{cluster: cluster, keyspace: keyspace, devices: devices}) do
    on_exit(fn ->
      DatabaseHelper.delete!(:device, cluster, keyspace, devices)
    end)

    DatabaseHelper.insert!(:device, cluster, keyspace, devices)
    :ok
  end
end
