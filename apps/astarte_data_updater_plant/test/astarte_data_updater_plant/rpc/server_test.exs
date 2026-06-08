#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

  use ExUnit.Case, async: true
  use Mimic
  use ExUnitProperties

  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.RPC.Server.Core

  setup_all do
    [{rpc_server, _}] = Horde.Registry.lookup(Registry.DataUpdaterRPC, :server)

    %{rpc_server: rpc_server}
  end

  setup %{rpc_server: rpc_server} do
    Core
    |> allow(self(), rpc_server)

    :ok
  end

  property ":install_volatile_trigger request gets handled by the Core module", %{
    rpc_server: rpc_server
  } do
    check all answer <- answer(), payload <- payload() do
      Core
      |> expect(:install_volatile_trigger, fn ^payload -> answer end)

      assert ^answer = GenServer.call(rpc_server, {:install_volatile_trigger, payload})
    end
  end

  property ":delete_volatile_trigger request gets handled by the Core module", %{
    rpc_server: rpc_server
  } do
    check all answer <- answer(), payload <- payload() do
      Core
      |> expect(:delete_volatile_trigger, fn ^payload -> answer end)

      assert ^answer = GenServer.call(rpc_server, {:delete_volatile_trigger, payload})
    end
  end

  test ":start_device_deletion request gets handled by the Core module", %{
    rpc_server: rpc_server
  } do
    realm_name = "realm#{System.unique_integer([:positive])}"
    device_id = Device.random_device_id()
    encoded_device_id = Device.encode_device_id(device_id)
    answer = :ok

    Core
    |> expect(:start_device_deletion, fn ^realm_name, ^encoded_device_id, timestamp ->
      assert is_integer(timestamp)
      microsecond_ts = timestamp |> div(10)
      assert {:ok, _datetime} = DateTime.from_unix(microsecond_ts, :microsecond)
      answer
    end)

    assert ^answer =
             GenServer.call(rpc_server, {:start_device_deletion, {realm_name, encoded_device_id}})
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
