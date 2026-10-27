#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin.Connection.Synchronizer.Supervisor do
  @moduledoc "Dynamic supervisor for per-device connection Synchronizer processes."
  # TODO a single dynamic supervisor may become a bottleneck,
  # use a PartitionSupervisor when on Elixir >= 1.14
  use DynamicSupervisor

  alias Astarte.VMQ.Plugin.Connection.Synchronizer

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(opts) do
    spec = Synchronizer.child_spec(opts)
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
