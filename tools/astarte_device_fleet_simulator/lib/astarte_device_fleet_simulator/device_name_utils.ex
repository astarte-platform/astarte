# Copyright 2021 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

defmodule AstarteDeviceFleetSimulator.DeviceNameUtils do
  use Agent
  alias AstarteDeviceFleetSimulator.Config

  @global_namespace "550e8400-e16b-41d4-a716-446655440000"

  def start_link(_initial_value) do
    Agent.start_link(fn -> generate_instance_namespace(Config.instance_id!()) end,
      name: __MODULE__
    )
  end

  def generate_device_name(device_value) do
    Agent.get(__MODULE__, & &1)
    |> UUID.uuid5("device-#{device_value}", :raw)
    |> Astarte.Core.Device.encode_device_id()
  end

  defp generate_instance_namespace(instance_id) do
    UUID.uuid5(@global_namespace, instance_id, :raw)
  end
end
