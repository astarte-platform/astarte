#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.Core.Triggers.SimpleEvents.Encoder do
  @moduledoc """
  JSON encoding implementations for SimpleEvents structs.
  """

  alias Astarte.Core.Triggers.SimpleEvents
  alias Astarte.Core.Triggers.SimpleEvents.Encoder

  defimpl Jason.Encoder, for: SimpleEvents.DeviceConnectedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent

    def encode(%DeviceConnectedEvent{} = event, opts) do
      %DeviceConnectedEvent{
        device_ip_address: device_ip_address
      } = event

      %{
        "type" => "device_connected",
        "device_ip_address" => device_ip_address
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.DeviceDisconnectedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.DeviceDisconnectedEvent

    def encode(%DeviceDisconnectedEvent{}, opts) do
      %{
        "type" => "device_disconnected"
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.DeviceErrorEvent do
    alias Astarte.Core.Triggers.SimpleEvents.DeviceErrorEvent

    def encode(%DeviceErrorEvent{} = event, opts) do
      %DeviceErrorEvent{
        error_name: error_name,
        metadata: metadata
      } = event

      metadata_map = Enum.into(metadata, %{})

      %{
        "type" => "device_error",
        "error_name" => error_name,
        "metadata" => metadata_map
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.DeviceRegisteredEvent do
    alias Astarte.Core.Triggers.SimpleEvents.DeviceRegisteredEvent

    def encode(%DeviceRegisteredEvent{}, opts) do
      %{
        "type" => "device_registered"
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.DeviceDeletionStartedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.DeviceDeletionStartedEvent

    def encode(%DeviceDeletionStartedEvent{}, opts) do
      %{
        "type" => "device_deletion_started"
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.DeviceDeletionFinishedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.DeviceDeletionFinishedEvent

    def encode(%DeviceDeletionFinishedEvent{}, opts) do
      %{
        "type" => "device_deletion_finished"
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.IncomingDataEvent do
    alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent

    def encode(%IncomingDataEvent{} = event, opts) do
      %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      } = event

      %{
        "type" => "incoming_data",
        "interface" => interface,
        "path" => path,
        "value" => Encoder.extract_bson_value(bson_value)
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.InterfaceVersion do
    alias SimpleEvents.InterfaceVersion

    def encode(interface_version, opts) do
      %InterfaceVersion{major: major, minor: minor} = interface_version

      %{
        "major" => major,
        "minor" => minor
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.IncomingIntrospectionEvent do
    alias Astarte.Core.Triggers.SimpleEvents.IncomingIntrospectionEvent

    def encode(%IncomingIntrospectionEvent{introspection: nil} = event, opts) do
      %IncomingIntrospectionEvent{
        introspection_map: introspection_map
      } = event

      %{
        "type" => "incoming_introspection",
        "introspection" => introspection_map
      }
      |> Jason.Encoder.encode(opts)
    end

    def encode(%IncomingIntrospectionEvent{} = event, opts) do
      %IncomingIntrospectionEvent{
        introspection: introspection
      } = event

      %{
        "type" => "incoming_introspection",
        "introspection" => introspection
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.InterfaceAddedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.InterfaceAddedEvent

    def encode(%InterfaceAddedEvent{} = event, opts) do
      %InterfaceAddedEvent{
        interface: interface,
        major_version: major_version,
        minor_version: minor_version
      } = event

      %{
        "type" => "interface_added",
        "interface" => interface,
        "major_version" => major_version,
        "minor_version" => minor_version
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.InterfaceMinorUpdatedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent

    def encode(%InterfaceMinorUpdatedEvent{} = event, opts) do
      %InterfaceMinorUpdatedEvent{
        interface: interface,
        major_version: major_version,
        old_minor_version: old_minor_version,
        new_minor_version: new_minor_version
      } = event

      %{
        "type" => "interface_minor_updated",
        "interface" => interface,
        "major_version" => major_version,
        "old_minor_version" => old_minor_version,
        "new_minor_version" => new_minor_version
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.InterfaceRemovedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.InterfaceRemovedEvent

    def encode(%InterfaceRemovedEvent{} = event, opts) do
      %InterfaceRemovedEvent{
        interface: interface,
        major_version: major_version
      } = event

      %{
        "type" => "interface_removed",
        "interface" => interface,
        "major_version" => major_version
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.PathCreatedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.PathCreatedEvent

    def encode(%PathCreatedEvent{} = event, opts) do
      %PathCreatedEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      } = event

      %{
        "type" => "path_created",
        "interface" => interface,
        "path" => path,
        "value" => Encoder.extract_bson_value(bson_value)
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.PathRemovedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent

    def encode(%PathRemovedEvent{} = event, opts) do
      %PathRemovedEvent{
        interface: interface,
        path: path
      } = event

      %{
        "type" => "path_removed",
        "interface" => interface,
        "path" => path
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.ValueChangeAppliedEvent do
    alias Astarte.Core.Triggers.SimpleEvents.ValueChangeAppliedEvent

    def encode(%ValueChangeAppliedEvent{} = event, opts) do
      %ValueChangeAppliedEvent{
        interface: interface,
        path: path,
        old_bson_value: old_bson_value,
        new_bson_value: new_bson_value
      } = event

      %{
        "type" => "value_change_applied",
        "interface" => interface,
        "path" => path,
        "old_value" => Encoder.extract_bson_value(old_bson_value),
        "new_value" => Encoder.extract_bson_value(new_bson_value)
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.ValueChangeEvent do
    alias Astarte.Core.Triggers.SimpleEvents.ValueChangeEvent

    def encode(%ValueChangeEvent{} = event, opts) do
      %ValueChangeEvent{
        interface: interface,
        path: path,
        old_bson_value: old_bson_value,
        new_bson_value: new_bson_value
      } = event

      %{
        "type" => "value_change",
        "interface" => interface,
        "path" => path,
        "old_value" => Encoder.extract_bson_value(old_bson_value),
        "new_value" => Encoder.extract_bson_value(new_bson_value)
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  defimpl Jason.Encoder, for: SimpleEvents.ValueStoredEvent do
    alias Astarte.Core.Triggers.SimpleEvents.ValueStoredEvent

    def encode(%ValueStoredEvent{} = event, opts) do
      %ValueStoredEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      } = event

      %{
        "type" => "value_stored",
        "interface" => interface,
        "path" => path,
        "value" => Encoder.extract_bson_value(bson_value)
      }
      |> Jason.Encoder.encode(opts)
    end
  end

  def extract_bson_value(nil) do
    # Handle nil bson value as nil
    nil
  end

  def extract_bson_value(<<>>) do
    # Handle empty binary bson value as nil
    nil
  end

  def extract_bson_value(bson_value) do
    case Cyanide.decode!(bson_value) do
      # Handle array types
      %{"v" => array} when is_list(array) ->
        Enum.map(array, &normalize_value/1)

      # With object aggregations we traverse all values to normalize them
      %{"v" => object} when is_map(object) and not is_struct(object) ->
        for {k, v} <- object, into: %{} do
          {k, normalize_value(v)}
        end

      %{"v" => value} ->
        normalize_value(value)

      other ->
        other
    end
  end

  # Special case: binary bson type must be base64 encoded
  defp normalize_value(%Cyanide.Binary{subtype: :generic, data: value}) do
    Base.encode64(value)
  end

  # Special case: make sure binary bson type is base64 encoded inside arrays in objects, too
  defp normalize_value(binary_array) when is_list(binary_array) do
    Enum.map(binary_array, &normalize_value/1)
  end

  defp normalize_value(value) do
    value
  end
end
