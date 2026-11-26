defmodule Astarte.DataUpdaterPlant.DataUpdater.ServerTest do
  use ExUnit.Case

  use Mimic

  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.DataUpdater.Server
  alias Astarte.DataUpdaterPlant.DataUpdater.State

  setup :verify_on_exit!

  test "handle_cast({:handle_signal, signal}) delegates to Impl" do
    state = %State{}

    expect(Impl, :handle_signal, fn :disconnect_device, _state ->
      %State{connected: false}
    end)

    {:noreply, new_state, _timeout} =
      Server.handle_cast({:handle_signal, :disconnect_device}, state)

    assert new_state.connected == false
  end
end
