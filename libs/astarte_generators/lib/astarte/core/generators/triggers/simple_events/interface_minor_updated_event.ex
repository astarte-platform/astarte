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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event InterfaceMinorUpdatedEvent struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  @spec interface_minor_updated_event() :: StreamData.t(InterfaceMinorUpdatedEvent.t())
  @spec interface_minor_updated_event(keyword :: keyword()) ::
          StreamData.t(InterfaceMinorUpdatedEvent.t())
  def interface_minor_updated_event(params \\ []) do
    params gen all interface <-
                     InterfaceGenerator.interface()
                     |> filter(fn %Interface{minor_version: minor_version} ->
                       minor_version < 255
                     end),
                   %Interface{
                     name: name,
                     major_version: major_version,
                     minor_version: minor_version
                   } = interface,
                   interface_name <- constant(name),
                   major_version <- constant(major_version),
                   old_minor_version <- constant(minor_version),
                   new_minor_version <- integer((minor_version + 1)..255),
                   params: params do
      %InterfaceMinorUpdatedEvent{
        interface: interface_name,
        major_version: major_version,
        old_minor_version: old_minor_version,
        new_minor_version: new_minor_version
      }
    end
  end
end
