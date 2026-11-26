defmodule Astarte.DataUpdaterPlant.DataUpdaterModuleTest do
  use ExUnit.Case

  alias Astarte.DataUpdaterPlant.DataUpdater

  test "handle_signal/2 casts signal to the given pid" do
    DataUpdater.handle_signal(self(), :disconnect_device)
    assert_receive {:"$gen_cast", {:handle_signal, :disconnect_device}}
  end
end
