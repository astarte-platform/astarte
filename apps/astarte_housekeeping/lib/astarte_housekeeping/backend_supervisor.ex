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

defmodule Astarte.Housekeeping.BackendSupervisor do
  @moduledoc false
  use Supervisor

  alias Astarte.Housekeeping.Config

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    Logger.info("BackendSupervisor init", tag: "housekeeping_backend_sup_init")

    xandra_options = Config.xandra_options!()
    data_access_opts = [xandra_options: xandra_options]

    children = [
      {Astarte.DataAccess, data_access_opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
