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

defmodule Astarte.RPC.RealmManagement do
  @moduledoc """
  RPC to a single Realm Management replica.
  This module should be present in the supervision trees of both the server and the clients in order to work properly.
  """
  use Supervisor

  alias Astarte.RPC.RealmManagement
  alias Astarte.RPC.RealmManagement.DeviceDeletion
  alias Horde.Registry

  @registry RealmManagement.Registry
  @server {:via, Registry, {@registry, :server}}

  def start_link(init_arg),
    do: Supervisor.start_link(RealmManagement, init_arg, name: RealmManagement)

  @impl Supervisor
  def init(_init_arg) do
    [
      {Registry, [keys: :unique, name: @registry, members: :auto]}
    ]
    |> Supervisor.init(strategy: :rest_for_one)
  end

  @spec server_name() :: GenServer.name()
  def server_name, do: @server

  @spec delete_device(String.t(), String.t()) :: :ok | {:error, term()}
  def delete_device(realm_name, encoded_device_id) do
    request = %DeviceDeletion{realm_name: realm_name, encoded_device_id: encoded_device_id}

    GenServer.call(@server, request)
  end
end
