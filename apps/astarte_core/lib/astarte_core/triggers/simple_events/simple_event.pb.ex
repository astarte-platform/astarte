defmodule Astarte.Core.Triggers.SimpleEvents.SimpleEvent do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof :event, 0

  field :version, 1, type: :int32, deprecated: true
  field :simple_trigger_id, 2, proto3_optional: true, type: :bytes, json_name: "simpleTriggerId"
  field :parent_trigger_id, 3, proto3_optional: true, type: :bytes, json_name: "parentTriggerId"
  field :realm, 4, proto3_optional: true, type: :string
  field :device_id, 5, proto3_optional: true, type: :string, json_name: "deviceId"
  field :timestamp, 18, proto3_optional: true, type: :int64

  field :device_connected_event, 6,
    type: Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent,
    json_name: "deviceConnectedEvent",
    oneof: 0

  field :device_disconnected_event, 7,
    type: Astarte.Core.Triggers.SimpleEvents.DeviceDisconnectedEvent,
    json_name: "deviceDisconnectedEvent",
    oneof: 0

  field :incoming_data_event, 8,
    type: Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent,
    json_name: "incomingDataEvent",
    oneof: 0

  field :value_change_event, 9,
    type: Astarte.Core.Triggers.SimpleEvents.ValueChangeEvent,
    json_name: "valueChangeEvent",
    oneof: 0

  field :value_change_applied_event, 10,
    type: Astarte.Core.Triggers.SimpleEvents.ValueChangeAppliedEvent,
    json_name: "valueChangeAppliedEvent",
    oneof: 0

  field :path_created_event, 11,
    type: Astarte.Core.Triggers.SimpleEvents.PathCreatedEvent,
    json_name: "pathCreatedEvent",
    oneof: 0

  field :path_removed_event, 12,
    type: Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent,
    json_name: "pathRemovedEvent",
    oneof: 0

  field :value_stored_event, 13,
    type: Astarte.Core.Triggers.SimpleEvents.ValueStoredEvent,
    json_name: "valueStoredEvent",
    oneof: 0

  field :incoming_introspection_event, 14,
    type: Astarte.Core.Triggers.SimpleEvents.IncomingIntrospectionEvent,
    json_name: "incomingIntrospectionEvent",
    oneof: 0

  field :interface_added_event, 15,
    type: Astarte.Core.Triggers.SimpleEvents.InterfaceAddedEvent,
    json_name: "interfaceAddedEvent",
    oneof: 0

  field :interface_removed_event, 16,
    type: Astarte.Core.Triggers.SimpleEvents.InterfaceRemovedEvent,
    json_name: "interfaceRemovedEvent",
    oneof: 0

  field :interface_minor_updated_event, 17,
    type: Astarte.Core.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent,
    json_name: "interfaceMinorUpdatedEvent",
    oneof: 0

  field :device_error_event, 19,
    type: Astarte.Core.Triggers.SimpleEvents.DeviceErrorEvent,
    json_name: "deviceErrorEvent",
    oneof: 0

  field :device_registered_event, 20,
    type: Astarte.Core.Triggers.SimpleEvents.DeviceRegisteredEvent,
    json_name: "deviceRegisteredEvent",
    oneof: 0

  field :device_deletion_started_event, 21,
    type: Astarte.Core.Triggers.SimpleEvents.DeviceDeletionStartedEvent,
    json_name: "deviceDeletionStartedEvent",
    oneof: 0

  field :device_deletion_finished_event, 22,
    type: Astarte.Core.Triggers.SimpleEvents.DeviceDeletionFinishedEvent,
    json_name: "deviceDeletionFinishedEvent",
    oneof: 0
end
