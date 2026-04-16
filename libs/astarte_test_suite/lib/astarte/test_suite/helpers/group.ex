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

defmodule Astarte.TestSuite.Helpers.Group do
  @moduledoc false

  import Astarte.TestSuite.CaseContext,
    only: [put!: 5, put_fixture: 3, reduce: 4, require_keys!: 3]

  def group_name(%{group_number: group_number}), do: "group-#{group_number}"

  def groups(%{group_name: group_name} = context) do
    reduce(context, :devices, context, fn device_id, device, _interface_id, acc ->
      group = group_for_device(device, group_name)
      put!(acc, :groups, group.id, group, device_id)
    end)
  end

  def data(context) do
    context
    |> require_keys!([:devices_registered?, :groups], :group_data)
    |> put_fixture(:group_data, %{groups_ready?: true})
  end

  # TODO: replace this mock group materialization with the real pipeline once
  # the corresponding generator/persistence flow exists.
  defp group_for_device(device, group_name),
    do: %{id: device.name <> "." <> group_name, name: group_name, device_id: device.name}
end
