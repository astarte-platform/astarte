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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.PathRemovedEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event PathRemovedEvent struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator

  @spec path_removed_event() :: StreamData.t(PathRemovedEvent.t())
  @spec path_removed_event(keyword :: keyword()) :: StreamData.t(PathRemovedEvent.t())
  def path_removed_event(params \\ []) do
    params gen all interface <- InterfaceGenerator.interface(),
                   %Interface{name: name} = interface,
                   package <- ValueGenerator.value(interface: interface),
                   %{path: path} = package,
                   interface_name <- constant(name),
                   path <- constant(path),
                   params: params,
                   exclude: [:interface, :package] do
      %PathRemovedEvent{
        interface: interface_name,
        path: path
      }
    end
  end
end
