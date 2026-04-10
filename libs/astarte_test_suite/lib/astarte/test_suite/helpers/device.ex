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

defmodule Astarte.TestSuite.Helpers.Device do
  @moduledoc false

  import Astarte.TestSuite.CaseContext,
    only: [put!: 5, put_fixture: 3, reduce: 4, require_keys!: 3]

  def devices(context) do
    reduce(context, :interfaces, context, fn interface_id, interface, _realm_id, acc ->
      device = device_for_interface(interface)
      put!(acc, :devices, device.name, device, interface_id)
    end)
  end

  def data(context) do
    context
    |> require_keys!([:interfaces_registered?, :devices], :device_data)
    |> put_fixture(:device_data, %{devices_registered?: true})
  end

  # TODO: replace this mock device materialization with the real pipeline once
  # the corresponding generator/persistence flow exists.
  defp device_for_interface(interface),
    do: %{name: interface.name <> ".device", interface_name: interface.name}
end
