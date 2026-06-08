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

defmodule Astarte.Helpers.Interface do
  @moduledoc """
  Test helper functions to customize interface mappings with shared parameters.
  """
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  @doc """
  Applies `params` to all mappings in an interface or list of interfaces.
  """
  @spec customize_mappings(interface :: Interface.t(), params :: keyword()) :: Interface.t()
  def customize_mappings(%Interface{mappings: mappings} = interface, params),
    do: %Interface{interface | mappings: Enum.map(mappings, &customize_mapping(&1, params))}

  @spec customize_mappings(interfaces :: list(Interface.t()), params :: keyword()) ::
          list(Interface.t())
  def customize_mappings([], _params), do: []

  def customize_mappings([%Interface{} | _] = interfaces, params),
    do: Enum.map(interfaces, &customize_mappings(&1, params))

  defp customize_mapping(%Mapping{} = mapping, params), do: struct!(mapping, params)
end
