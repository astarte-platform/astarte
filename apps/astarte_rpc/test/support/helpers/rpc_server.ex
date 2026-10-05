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

defmodule Astarte.RPC.Helpers.RPCServer do
  @moduledoc """
  Mock RPC Server which sends messages back to the test process.
  """

  use GenServer

  alias Astarte.RPC.Helpers.RPCServer

  def start_link(opts) do
    {name, opts} = Keyword.pop!(opts, :name)

    opts =
      opts
      |> Keyword.put_new(:id, :rpc_server)
      |> Keyword.put_new(:receiver, self())

    GenServer.start_link(RPCServer, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    receiver = Keyword.fetch!(opts, :receiver)

    {:ok, %{id: id, receiver: receiver}}
  end

  @impl true
  def handle_call(message, _from, state) do
    %{id: id, receiver: receiver} = state
    message = {:call, id, message}
    send(receiver, message)

    {:reply, :ok, state}
  end
end
