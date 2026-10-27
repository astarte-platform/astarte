defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger.DeviceEventType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :INVALID, 0
  field :DEVICE_CONNECTED, 1
  field :DEVICE_DISCONNECTED, 2
  field :DEVICE_EMPTY_CACHE_RECEIVED, 3
  field :DEVICE_ERROR, 4
  field :INCOMING_INTROSPECTION, 5
  field :INTERFACE_ADDED, 6
  field :INTERFACE_REMOVED, 7
  field :INTERFACE_MINOR_UPDATED, 8
  field :DEVICE_REGISTERED, 9
  field :DEVICE_DELETION_STARTED, 10
  field :DEVICE_DELETION_FINISHED, 11
end

defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :version, 1, type: :int32, deprecated: true

  field :device_event_type, 2,
    type: Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger.DeviceEventType,
    json_name: "deviceEventType",
    enum: true

  field :device_id, 3, proto3_optional: true, type: :string, json_name: "deviceId"
  field :group_name, 4, proto3_optional: true, type: :string, json_name: "groupName"
  field :interface_name, 5, proto3_optional: true, type: :string, json_name: "interfaceName"
  field :interface_major, 6, type: :int32, json_name: "interfaceMajor"
end
