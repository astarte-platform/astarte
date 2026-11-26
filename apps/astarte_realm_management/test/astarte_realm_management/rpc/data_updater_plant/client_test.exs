defmodule Astarte.RealmManagement.RPC.DataUpdaterPlant.ClientTest do
  use ExUnit.Case

  alias Astarte.RealmManagement.RPC.DataUpdaterPlant.Client
  alias Astarte.RealmManagement.Test.DataUpdaterRPCServer

  test "interface_installed_rpc/3 sends an RPC call" do
    # The RPC server is sometimes started asynchronously by test_helper.exs
    case DataUpdaterRPCServer.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Give Horde.Registry some time to register the name
    Process.sleep(200)

    # Since we have Astarte.RealmManagement.Test.DataUpdaterRPCServer running
    # we can just call it and ensure it returns :ok
    assert :ok = Client.interface_installed_rpc("test_realm", "org.test.Interface", 1)
  end
end
