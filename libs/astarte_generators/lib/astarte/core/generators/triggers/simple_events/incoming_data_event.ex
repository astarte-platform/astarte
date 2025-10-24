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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.IncomingDataEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event IncomingDataEvent struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping.BSONValue, as: BSONValueGenerator
  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator

  @spec incoming_data_event() :: StreamData.t(IncomingDataEvent.t())
  @spec incoming_data_event(keyword :: keyword()) :: StreamData.t(IncomingDataEvent.t())
  def incoming_data_event(params \\ []) do
    params gen all :_,
                   %Interface{name: name} = interface <- InterfaceGenerator.interface(),
                   :_,
                   %{path: path} = package <- ValueGenerator.value(interface: interface),
                   :interface,
                   interface_name <- constant(name),
                   path <- constant(path),
                   bson_value <- BSONValueGenerator.to_bson(%{package | path: path}),
                   params: params do
      %IncomingDataEvent{
        interface: interface_name,
        path: path,
        bson_value: bson_value
      }
    end
  end
end
