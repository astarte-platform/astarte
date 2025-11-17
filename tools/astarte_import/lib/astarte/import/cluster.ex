# This file is part of Astarte.
#
# Copyright 2025 SECO Mind
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

defmodule Astarte.Import.Cluster do
  @moduledoc false

  @cluster_name :astarte_data_access_xandra

  @spec ensure_registered() :: :ok
  def ensure_registered() do
    true =
      Astarte.DataAccess
      |> Supervisor.which_children()
      |> Enum.find_value(fn {id, pid, _, _} -> id == Astarte.DataAccess.Repo && pid end)
      |> Supervisor.which_children()
      |> Enum.find_value(fn {id, pid, _, _} -> id == Astarte.DataAccess.Repo && pid end)
      |> Process.register(@cluster_name)

    :ok
  end
end
