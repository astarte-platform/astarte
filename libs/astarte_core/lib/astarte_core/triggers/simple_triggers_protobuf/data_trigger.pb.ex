defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger.DataTriggerType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :INVALID, 0
  field :INCOMING_DATA, 1
  field :VALUE_CHANGE, 2
  field :VALUE_CHANGE_APPLIED, 3
  field :PATH_CREATED, 4
  field :PATH_REMOVED, 5
  field :VALUE_STORED, 6
end

defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger.MatchOperator do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :INVALID_OPERATOR, 0
  field :ANY, 1
  field :EQUAL_TO, 2
  field :NOT_EQUAL_TO, 3
  field :GREATER_THAN, 4
  field :GREATER_OR_EQUAL_TO, 5
  field :LESS_THAN, 6
  field :LESS_OR_EQUAL_TO, 7
  field :CONTAINS, 8
  field :NOT_CONTAINS, 9
end

defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :version, 1, type: :int32, deprecated: true

  field :data_trigger_type, 2,
    type: Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger.DataTriggerType,
    json_name: "dataTriggerType",
    enum: true

  field :interface_name, 3, proto3_optional: true, type: :string, json_name: "interfaceName"
  field :interface_major, 4, type: :int32, json_name: "interfaceMajor"
  field :match_path, 5, proto3_optional: true, type: :string, json_name: "matchPath"

  field :value_match_operator, 6,
    type: Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger.MatchOperator,
    json_name: "valueMatchOperator",
    enum: true

  field :known_value, 7, proto3_optional: true, type: :bytes, json_name: "knownValue"
  field :device_id, 8, proto3_optional: true, type: :string, json_name: "deviceId"
  field :group_name, 9, proto3_optional: true, type: :string, json_name: "groupName"
end
