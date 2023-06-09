#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Astarte.DataAccess do
  # Automatically defines child_spec/1
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    xandra_options =
      Keyword.fetch!(init_arg, :xandra_options)
      |> Keyword.put(:name, :astarte_data_access_xandra)
      # TODO move to string keys
      |> Keyword.put(:atom_keys, true)

    children = [
      {Xandra.Cluster, xandra_options}
    ]

    opts = [strategy: :one_for_one, name: Astarte.DataAccess.Supervisor]
    Supervisor.init(children, opts)
  end
end
