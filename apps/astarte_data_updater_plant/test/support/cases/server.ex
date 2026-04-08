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

defmodule Astarte.Cases.Server do
  @moduledoc """
  This module defines test cases for GenServer behavior.
  """
  use ExUnit.CaseTemplate

  defmodule Astarte.Cases.Server.PingPong do
    @moduledoc false
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    @impl true
    def init(opts) do
      parent = Keyword.fetch!(opts, :parent)
      {:ok, parent}
    end

    @impl true
    def handle_call(request, _, parent) do
      send(parent, {:call, request})
      {:reply, request, parent}
    end

    @impl true
    def handle_cast(request, parent) do
      send(parent, {:cast, request})
      {:noreply, parent}
    end
  end

  defmodule Astarte.Cases.Server.Ignore do
    @moduledoc false
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    @impl true
    def init(_opts) do
      {:ok, nil}
    end

    @impl true
    def handle_call(_request, _, state) do
      {:noreply, state}
    end
  end

  alias Astarte.Cases.Server.Ignore
  alias Astarte.Cases.Server.PingPong

  setup do
    ping_pong = start_link_supervised!({PingPong, parent: self()})
    ignore = start_link_supervised!(Ignore)

    %{ignore: ignore, ping_pong: ping_pong}
  end
end
