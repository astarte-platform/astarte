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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.InterfaceRemovedEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event InterfaceRemovedEvent struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Triggers.SimpleEvents.InterfaceRemovedEvent

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  @spec interface_removed_event() :: StreamData.t(InterfaceRemovedEvent.t())
  @spec interface_removed_event(keyword :: keyword()) :: StreamData.t(InterfaceRemovedEvent.t())
  def interface_removed_event(params \\ []) do
    params gen all interface <- InterfaceGenerator.name(),
                   major_version <- InterfaceGenerator.major_version(),
                   params: params do
      %InterfaceRemovedEvent{
        interface: interface,
        major_version: major_version
      }
    end
  end
end
