defmodule Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :device_ip_address, 1, proto3_optional: true, type: :string, json_name: "deviceIpAddress"
end
