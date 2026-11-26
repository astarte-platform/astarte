defmodule Astarte.DataUpdaterPlant.DataUpdater.ImplTest do
  use ExUnit.Case

  use Mimic

  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.DataUpdater.State

  setup :verify_on_exit!

  test "handle_signal(:disconnect_device) asks for clean session" do
    state = %State{}

    expect(Core.Device, :ask_clean_session, fn _state, _timestamp ->
      {:ok, %State{connected: false}}
    end)

    new_state = Impl.handle_signal(:disconnect_device, state)
    assert new_state.connected == false
  end
end
