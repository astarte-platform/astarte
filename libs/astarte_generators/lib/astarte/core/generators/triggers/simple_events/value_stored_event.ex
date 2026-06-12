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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.ValueStoredEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event ValueStoredEvent struct.
  """
  use ExUnitProperties

  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.Mapping.BSONValue
  import Astarte.Core.Generators.Mapping.Value

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleEvents.ValueStoredEvent

  @spec value_stored_event() :: StreamData.t(ValueStoredEvent.t())
  @spec value_stored_event(keyword :: keyword()) :: StreamData.t(ValueStoredEvent.t())
  def value_stored_event(params \\ []) do
    params gen all interface <- interface(),
                   %Interface{name: name} = interface,
                   value <- value(interface: interface),
                   %{path: path} = value,
                   interface_name <- constant(name),
                   path <- constant(path),
                   bson_value <- to_bson(%{value | path: path}),
                   params: params do
      %ValueStoredEvent{
        interface: interface_name,
        path: path,
        bson_value: bson_value
      }
    end
  end
end
