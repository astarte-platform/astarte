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
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Device, only: [device_encoded_id: 0]
  import Astarte.Core.Generators.Group, only: [group_name: 0]

  @type scope_t ::
          %{}
          | %{device_id: String.t()}
          | %{group_name: String.t()}

  @doc false
  @spec trigger_scope() :: StreamData.t(scope_t())
  @spec trigger_scope(keyword()) :: StreamData.t(scope_t())
  def trigger_scope(params \\ []) do
    params gen all type <- member_of([:any_device, :device, :group]),
                   scope <- scope(type),
                   params: params,
                   exclude: [:scope] do
      scope
    end
  end

  defp scope(:any_device), do: constant(%{})

  defp scope(:device), do: device_encoded_id() |> map(&%{device_id: &1})

  defp scope(:group), do: group_name() |> map(&%{group_name: &1})
end
