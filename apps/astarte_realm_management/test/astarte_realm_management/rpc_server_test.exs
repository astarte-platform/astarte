#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.RealmManagement.RPC.ServerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.RealmManagement.Devices
  alias Astarte.RealmManagement.RPC.Server
  alias Astarte.RPC.RealmManagement

  import Astarte.Core.Generators.Realm
  import Astarte.Core.Generators.Device

  setup_all do
    [{rpc_server, _}] = Horde.Registry.lookup(Astarte.RPC.RealmManagement.Registry, :server)

    %{rpc_server: rpc_server}
  end

  setup %{rpc_server: rpc_server} do
    Devices
    |> allow(self(), rpc_server)

    :ok
  end

  test "DeviceDeletion calls delete_device" do
    realm_name = realm_name() |> Enum.at(0)
    encoded_device_id = encoded_id() |> Enum.at(0)

    Devices
    |> expect(:delete_device, fn ^realm_name, ^encoded_device_id -> :ok end)

    assert RealmManagement.delete_device(realm_name, encoded_device_id) == :ok
  end

  describe "shuts down" do
    setup :mock_rpc_server

    test "on `:name_conflict`", %{rpc_server: rpc_server} do
      name_conflict = {:EXIT, self(), {:name_conflict, {:rpc_server, nil}, nil, nil}}
      assert {:stop, :shutdown, _} = wait_send(rpc_server, name_conflict)
    end

    test "on `:shutdown`", %{rpc_server: rpc_server} do
      name_conflict = {:EXIT, self(), :shutdown}
      assert {:stop, :shutdown, _} = wait_send(rpc_server, name_conflict)
    end
  end

  defp wait_send(dest, message) do
    send(dest, message)

    assert_receive {:trace, ^dest, :call, {_, :handle_info, [^message, _]}}

    receive do
      {:trace, ^dest, :return_from, {_, :handle_info, 2}, result} ->
        result
    after
      100 -> flunk("no message in mailbox after 100ms")
    end
  end

  defp mock_rpc_server(_context) do
    mock_rpc_spec = %{id: :rpc_server, start: {GenServer, :start_link, [Server, nil]}}
    rpc_server = start_supervised!(mock_rpc_spec)

    :erlang.trace(rpc_server, true, [:call])
    :erlang.trace_pattern({Server, :_, :_}, [{:_, [], [{:return_trace}]}])

    %{rpc_server: rpc_server}
  end
end
