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

defmodule Astarte.Housekeeping.Config.ReplicationStrategy do
  @moduledoc """
  The replication strategy to use for the astarte keyspace
  """
  use Skogsra.Type

  @impl Skogsra.Type
  def cast("SimpleStrategy"), do: {:ok, :simple_strategy}
  def cast("NetworkTopologyStrategy"), do: {:ok, :network_topology_strategy}

  @impl Skogsra.Type
  def cast(_) do
    :error
  end
end
