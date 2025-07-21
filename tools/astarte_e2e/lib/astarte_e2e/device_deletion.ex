defmodule AstarteE2E.DeviceDeletion do
  use GenStateMachine

  alias AstarteE2E.Config
  alias AstarteE2E.Device

  def name, do: "device deletion"

  def start_link(init_arg) do
    GenStateMachine.start_link(__MODULE__, init_arg)
  end

  @impl GenStateMachine
  def init(_init_arg) do
    with {:ok, realm} <- Config.realm() do
      Process.flag(:trap_exit, true)
      device_id = Astarte.Core.Device.random_device_id()
      device_opts = [realm: realm, device_id: device_id]

      {:ok, device_pid} = Device.start_link(device_opts)

      Process.exit(device_pid, :normal)

      state = %{device_id: device_id, realm: realm, device_pid: device_pid}

      {:ok, :init, state}
    end
  end

  @impl true
  def handle_event(:info, {:EXIT, device_pid, _}, :init, %{device_pid: device_pid} = state) do
    start_device_deletion(state.realm, state.device_id)

    # Nothing to do for now, consider this a success
    {:stop, :normal}
  end

  defp start_device_deletion(realm, device_id) do
    realm_management_url = Config.realm_management_url!()

    astarte_jwt = Config.jwt!()
    encoded_id = Astarte.Core.Device.encode_device_id(device_id)

    url = Path.join([realm_management_url, "v1", realm, "devices", encoded_id])

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    %HTTPoison.Response{status_code: 204} = HTTPoison.delete!(url, headers)

    :ok
  end
end
