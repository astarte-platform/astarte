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

defmodule Astarte.DataUpdaterPlant.Config.ClusteringStrategy do
  @moduledoc """
  The clustering strategy that the node should use to discover other nodes.
  """

  use Skogsra.Type

  @allowed_strategies ~w(none kubernetes docker-compose)

  @impl Skogsra.Type
  def cast(value) when value in @allowed_strategies do
    {:ok, value}
  end

  @impl Skogsra.Type
  def cast(_) do
    :error
  end
end
