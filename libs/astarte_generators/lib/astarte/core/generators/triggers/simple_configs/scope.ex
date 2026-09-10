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

defmodule Astarte.Core.Generators.Triggers.SimpleConfigs.Scope do
  @moduledoc false
  use ExUnitProperties

  import Astarte.Core.Generators.Device, only: [device_encoded_id: 0]
  import Astarte.Core.Generators.Group, only: [group_name: 0]

  @doc false
  @spec trigger_scope() ::
          StreamData.t(%{device_id: String.t() | nil, group_name: String.t() | nil})
  def trigger_scope,
    do: one_of([any_device_scope(), device_scope(), group_scope()])

  defp any_device_scope,
    do: fixed_map(%{device_id: constant("*"), group_name: constant(nil)})

  defp device_scope,
    do: fixed_map(%{device_id: device_encoded_id(), group_name: constant(nil)})

  defp group_scope,
    do: fixed_map(%{device_id: constant(nil), group_name: group_name()})
end
