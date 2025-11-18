#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.RPC.ServerTest do
  @moduledoc false

  use Astarte.Cases.Trigger, async: true
  use Mimic
  use ExUnitProperties

  setup_all do
    [{rpc_server, _}] = Horde.Registry.lookup(Registry.DataUpdaterRPC, :server)

    %{rpc_server: rpc_server}
  end

  setup :verify_on_exit!

  property ":install_volatile_trigger request gets handled by the Core module", %{
    rpc_server: rpc_server
  } do
    check all answer <- answer(), payload <- payload() do
      Astarte.DataUpdaterPlant.RPC.Server.Core
      |> allow(self(), rpc_server)
      |> expect(:install_volatile_trigger, fn ^payload -> answer end)

      assert ^answer = GenServer.call(rpc_server, {:install_volatile_trigger, payload})
    end
  end

  property ":delete_volatile_trigger request gets handled by the Core module", %{
    rpc_server: rpc_server
  } do
    check all answer <- answer(), payload <- payload() do
      Astarte.DataUpdaterPlant.RPC.Server.Core
      |> allow(self(), rpc_server)
      |> expect(:delete_volatile_trigger, fn ^payload -> answer end)

      assert ^answer = GenServer.call(rpc_server, {:delete_volatile_trigger, payload})
    end
  end

  test ":install_trigger request gets handled by the Core module", context do
    %{
      policy: policy,
      realm_name: realm_name,
      rpc_server: rpc_server,
      tagged_simple_trigger: tagged_simple_trigger,
      trigger_target: trigger_target
    } = context

    test_process = self()

    Astarte.DataUpdaterPlant.RPC.Server.Core
    |> expect(:install_trigger, fn
      ^realm_name, ^tagged_simple_trigger, ^trigger_target, ^policy ->
        send(test_process, :ok)
        :ok
    end)
    |> allow(self(), rpc_server)

    message = {realm_name, tagged_simple_trigger, trigger_target, policy}
    GenServer.cast(rpc_server, {:install_trigger, message})

    assert_receive :ok
  end

  defp answer, do: one_of([oks(), errors()])

  defp oks do
    gen all term <- binary() do
      {:ok, term}
    end
  end

  defp errors do
    gen all term <- binary() do
      {:error, term}
    end
  end

  defp payload, do: binary()
end
