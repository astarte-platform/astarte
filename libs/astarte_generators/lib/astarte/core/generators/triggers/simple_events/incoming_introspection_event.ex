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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.IncomingIntrospectionEvent do
  @moduledoc """
  This module provides generators for Astarte Trigger Simple Event IncomingIntrospectionEvent struct.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleEvents.IncomingIntrospectionEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceVersion

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  @spec incoming_introspection_event() :: StreamData.t(IncomingIntrospectionEvent.t())
  @spec incoming_introspection_event(keyword :: keyword()) ::
          StreamData.t(IncomingIntrospectionEvent.t())
  def incoming_introspection_event(params \\ []) do
    params gen all interfaces <- InterfaceGenerator.interface() |> list_of(max_length: 10),
                   params: params do
      introspection_map =
        interfaces
        |> Enum.map(fn %Interface{
                         name: name,
                         major_version: major_version,
                         minor_version: minor_version
                       } ->
          {name, major_version, minor_version}
        end)
        |> Map.new(fn {name, major_version, minor_version} ->
          {name,
           %InterfaceVersion{
             major: major_version,
             minor: minor_version
           }}
        end)

      %IncomingIntrospectionEvent{
        introspection_map: introspection_map
      }
    end
  end
end
