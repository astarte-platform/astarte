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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.ValueChangeAppliedEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event ValueChangeAppliedEvent struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleEvents.ValueChangeAppliedEvent

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping.BSONValue, as: BSONValueGenerator
  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator

  @spec value_change_applied_event() :: StreamData.t(ValueChangeAppliedEvent.t())
  @spec value_change_applied_event(keyword :: keyword()) ::
          StreamData.t(ValueChangeAppliedEvent.t())
  def value_change_applied_event(params \\ []) do
    params gen all interface <- InterfaceGenerator.interface(),
                   %Interface{name: name} = interface,
                   value <- ValueGenerator.value(interface: interface),
                   %{path: path, type: value_type} = value,
                   interface_name <- constant(name),
                   path <- constant(path),
                   old_bson_value <- BSONValueGenerator.to_bson(%{value | path: path}),
                   new_bson_value <-
                     BSONValueGenerator.bson_value(
                       interface: interface,
                       path: path,
                       type: value_type
                     ),
                   params: params do
      %ValueChangeAppliedEvent{
        interface: interface_name,
        path: path,
        old_bson_value: old_bson_value,
        new_bson_value: new_bson_value
      }
    end
  end
end
