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

defmodule Astarte.DataUpdaterPlant.RPC.VMQPlugin.Client do
  @moduledoc false
  @behaviour Astarte.DataUpdaterPlant.RPC.VMQPlugin.Behaviour

  defp rpc_server, do: {:via, Horde.Registry, {Registry.VMQPluginRPC, :server}}

  @impl Astarte.DataUpdaterPlant.RPC.VMQPlugin.Behaviour
  def publish(data) do
    rpc_server()
    |> GenServer.call({:publish, data})
  end

  @impl Astarte.DataUpdaterPlant.RPC.VMQPlugin.Behaviour
  def delete(data) do
    rpc_server()
    |> GenServer.call({:delete, data})
  end

  @impl Astarte.DataUpdaterPlant.RPC.VMQPlugin.Behaviour
  def disconnect(data) do
    rpc_server()
    |> GenServer.call({:disconnect, data})
  end
end
