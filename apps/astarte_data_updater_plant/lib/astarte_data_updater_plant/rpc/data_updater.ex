defmodule Astarte.DataUpdaterPlant.RPC.DataUpdater do
  defp server_via_tuple(), do: {:via, Horde.Registry, {Registry.DataUpdaterRPC, :server}}

  def add_device(device) do
    server_via_tuple()
    |> GenServer.call({:add_device, device})
  end

  def remove_device(device_id) do
    server_via_tuple()
    |> GenServer.call({:remove_device, device_id})
  end

  def update_device_groups(device_id, groups) do
    server_via_tuple()
    |> GenServer.call({:update_device_groups, device_id, groups})
  end
end
