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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.ValueChangeEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event ValueChangeEvent struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleEvents.ValueChangeEvent

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping.BSONValue, as: BSONValueGenerator
  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator

  @spec value_change_event() :: StreamData.t(ValueChangeEvent.t())
  @spec value_change_event(keyword :: keyword()) :: StreamData.t(ValueChangeEvent.t())
  def value_change_event(params \\ []) do
    params gen all :_,
                   %Interface{name: name} = interface <- InterfaceGenerator.interface(),
                   :_,
                   %{path: path, type: type} = package <-
                     ValueGenerator.value(interface: interface),
                   :interface,
                   interface_name <- constant(name),
                   path <- constant(path),
                   old_bson_value <- BSONValueGenerator.to_bson(%{package | path: path}),
                   new_bson_value <-
                     BSONValueGenerator.bson_value(interface: interface, path: path, type: type),
                   params: params do
      %ValueChangeEvent{
        interface: interface_name,
        path: path,
        old_bson_value: old_bson_value,
        new_bson_value: new_bson_value
      }
    end
  end
end
