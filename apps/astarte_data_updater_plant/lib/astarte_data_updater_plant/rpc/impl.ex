defmodule Astarte.DataUpdaterPlant.RPC.Impl do
  alias ElixirSense.Log
  alias Astarte.DataUpdaterPlant.RPC.State
  alias Astarte.DataUpdaterPlant.RPC.Device
  alias Astarte.DataUpdaterPlant.RPC.Queries
  require Logger

  # State initialization by retrieving state via DB queries
  def init_state() do
    Logger.info("Initializing dup rpc handler state ...")
    Logger.info("Fetching realms ...")

    realms = retrieve_realms()
    Logger.info("Retrieved realms: #{inspect(realms)}")

    devices =
      realms
      |> Enum.reduce(%{}, fn realm, acc ->
        Logger.info("Fetching connected devices for realm: #{realm} ...")

        case retrieve_connected_devices(realm) do
          {:ok, realm_devices} ->
            Logger.info("Connected devices for realm #{realm} are: #{inspect(realm_devices)}")

            Enum.reduce(realm_devices, acc, fn device, acc_map ->
              Map.put(acc_map, device.device_id, device)
            end)

          {:error, reason} ->
            Logger.error("Failed to fetch devices for realm #{realm}: #{inspect(reason)}")
            acc
        end
      end)

    %State{
      devices: devices
    }
  end

  def get_trigger_installation_scope(simple_trigger) do
    case simple_trigger do
      {:data_trigger, %Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger{} = data_trigger} ->
        cond do
          Map.has_key?(data_trigger, :group_name) and not is_nil(data_trigger.group_name) ->
            {:data_trigger_group, data_trigger.group_name}

          Map.has_key?(data_trigger, :device_id) and not is_nil(data_trigger.device_id) ->
            {:data_trigger_device, data_trigger.device_id}

          true ->
            {:all, nil}
        end

      {:device_trigger,
       %Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger{device_id: device_id}} ->
        {:device, device_id}

      _ ->
        {:unknown, nil}
    end
  end

  def get_devices_to_notify(%State{} = state, scope) do
    case scope do
      {:all, nil} ->
        state
        |> fetch_all_devices()
        |> Enum.map(fn %Device{device_id: device_id, realm: realm} -> {device_id, realm} end)

      {:data_trigger_group, group_name} ->
        state
        |> fetch_devices_by_group(group_name)
        |> Enum.map(fn %Device{device_id: device_id, realm: realm} -> {device_id, realm} end)

      {:device, device_id} ->
        case fetch_device_by_id(state, device_id) do
          {:ok, {device_id, realm}} ->
            [{device_id, realm}]

          {:error, :device_not_found} ->
            Logger.error("Device with ID #{device_id} not found.")
            []
        end

      {:data_trigger_device, device_id} ->
        case fetch_device_by_id(state, device_id) do
          {:ok, {device_id, realm}} ->
            [{device_id, realm}]

          {:error, :device_not_found} ->
            Logger.error("Device with ID #{device_id} not found.")
            []
        end

      _ ->
        Logger.error("Unknown scope for trigger installation detected: #{inspect(scope)}")
        []
    end
  end

  def retrieve_realms() do
    realms = Queries.fetch_realms!()
  end

  def convert_extended_device_id_to_string(extended_device_id) do
    binary_id = Ecto.UUID.dump!(extended_device_id)
    string_id = Astarte.Core.Device.encode_device_id(binary_id)
  end

  def retrieve_connected_devices(realm) do
    Queries.fetch_connected_devices(realm)
    |> case do
      {:ok, devices} ->
        converted_id_devices =
          Enum.map(devices, fn %Device{} = device ->
            %Device{device | device_id: convert_extended_device_id_to_string(device.device_id)}
          end)

        {:ok, converted_id_devices}

      {:error, reason} ->
        Logger.error("Failed to fetch connected devices for realm #{realm}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def fetch_devices_by_group(%State{devices: devices}, group) do
    devices
    |> Map.values()
    |> Enum.filter(fn %Device{groups: groups} -> groups && group in groups end)
  end

  def fetch_device_by_id(%State{devices: devices}, device_id) do
    case Map.get(devices, device_id) do
      nil ->
        {:error, :device_not_found}

      %Device{device_id: device_id, realm: realm} ->
        {:ok, {device_id, realm}}
    end
  end

  def fetch_all_devices(%State{devices: devices}) do
    Map.values(devices)
  end

  def add_device(%State{devices: devices} = state, %Device{device_id: device_id} = device) do
    Logger.debug("add_device called with state: #{inspect(state)}, device: #{inspect(device)}")

    updated_devices = Map.put(devices, device_id, device)
    Logger.debug("Updated devices map: #{inspect(updated_devices)}")

    %State{state | devices: updated_devices}
  end

  def remove_device(%State{devices: devices} = state, device_id) do
    updated_devices = Map.delete(devices, device_id)
    %State{state | devices: updated_devices}
  end

  def update_device_groups(%State{devices: devices} = state, device_id, new_groups) do
    case Map.get(devices, device_id) do
      nil ->
        {:error, :device_not_found}

      %Device{} = device ->
        updated_device = %Device{device | groups: new_groups}
        updated_devices = Map.put(devices, device_id, updated_device)
        %State{state | devices: updated_devices}
    end
  end
end
