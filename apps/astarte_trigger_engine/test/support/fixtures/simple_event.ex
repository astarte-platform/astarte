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

defmodule Astarte.Fixtures.SimpleEvent do
  @moduledoc """
  Fixtures for simple event test data.
  """

  alias Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent
  alias Astarte.Core.Triggers.SimpleEvents.DeviceErrorEvent
  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent
  alias Astarte.Core.Triggers.SimpleEvents.IncomingIntrospectionEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleEvents.ValueChangeEvent

  def simple_events do
    incoming_data_event_individual = %IncomingDataEvent{
      interface: "com.example.Interface",
      path: "/my_path",
      bson_value: Cyanide.encode!(%{v: %Cyanide.Binary{subtype: :generic, data: <<1, 2, 3>>}})
    }

    _incoming_data_event_object = %IncomingDataEvent{
      interface: "org.astarte-platform.genericsensors.ServerOwnedAggregateObj",
      path: "/my_path",
      bson_value: Cyanide.encode!(%{v: %{"enable" => true, "samplingPeriod" => 10}})
    }

    value_change_event_individual = %ValueChangeEvent{
      interface: "com.example.Interface",
      path: "/my_path",
      old_bson_value: Cyanide.encode!(%{v: 4}),
      new_bson_value: Cyanide.encode!(%{v: 5})
    }

    _value_change_event_object = %ValueChangeEvent{
      interface: "org.astarte-platform.genericsensors.ServerOwnedAggregateObj",
      path: "/my_path",
      old_bson_value: Cyanide.encode!(%{v: %{"enable" => true, "samplingPeriod" => 10}}),
      new_bson_value: Cyanide.encode!(%{v: %{"enable" => false, "samplingPeriod" => 11}})
    }

    incoming_introspection_event = %IncomingIntrospectionEvent{
      introspection_map: %{
        "com.example.Interface" => %Astarte.Core.Triggers.SimpleEvents.InterfaceVersion{
          major: 1,
          minor: 2
        }
      }
    }

    # TODO: use generator

    # TODO: remove commented out sections after
    # https://github.com/astarte-platform/astarte/issues/1203 is resolved
    [
      %SimpleEvent{
        event: {:device_connected_event, %DeviceConnectedEvent{device_ip_address: "10.0.0.1"}},
        device_id: "f0VMRgIBAQAAAAAAAAAAAA",
        timestamp: 10,
        realm: "autotestrealm"
      },
      %SimpleEvent{
        event:
          {:device_error_event, %DeviceErrorEvent{error_name: "invalid_path", metadata: %{}}},
        device_id: "f0VMRgIBAQAAAAAAAAAAAA",
        realm: "autotestrealm"
      },
      %SimpleEvent{
        event: {:incoming_data_event, incoming_data_event_individual},
        device_id: "f0VMRgIBAQAAAAAAAAAAAA",
        realm: "autotestrealm"
      },
      # %SimpleEvent{
      #   event: {:incoming_data_event, incoming_data_event_object},
      #   device_id: "f0VMRgIBAQAAAAAAAAAAAA",
      #   realm: "autotestrealm"
      # },
      %SimpleEvent{
        event: {:value_change_event, value_change_event_individual},
        device_id: "f0VMRgIBAQAAAAAAAAAAAA",
        realm: "autotestrealm"
      },
      # %SimpleEvent{
      #   event: {:value_change_event, value_change_event_object},
      #   device_id: "f0VMRgIBAQAAAAAAAAAAAA",
      #   realm: "autotestrealm"
      # },
      %SimpleEvent{
        event: {:incoming_introspection_event, incoming_introspection_event},
        device_id: "f0VMRgIBAQAAAAAAAAAAAA",
        realm: "autotestrealm"
      }
    ]
  end
end
