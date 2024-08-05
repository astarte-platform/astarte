defmodule Astarte.Test.Setups.Device do
  use ExUnit.Case, async: false
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper
  alias Astarte.Test.Generators.Device, as: DeviceGenerator

  def init(%{device_count: device_count, interfaces: interfaces}) do
    {:ok, devices: DeviceGenerator.device(interfaces: interfaces) |> Enum.take(device_count)}
  end

  def setup(%{cluster: cluster, keyspace: keyspace, devices: devices}) do
    on_exit(fn ->
      DatabaseHelper.delete!(:device, cluster, keyspace, devices)
    end)

    DatabaseHelper.insert!(:device, cluster, keyspace, devices)
    :ok
  end
end
