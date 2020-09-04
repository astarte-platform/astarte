#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E.Scheduler do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    check_interval_ms =
      Keyword.fetch!(opts, :check_interval_s)
      |> to_ms()

    children = [
      %{
        id: :scheduled_task,
        start: {SchedEx, :run_in, [AstarteE2E, :test, [], check_interval_ms]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp to_ms(seconds), do: seconds * 1_000
end
