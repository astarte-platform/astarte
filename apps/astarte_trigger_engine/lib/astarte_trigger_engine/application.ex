#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.TriggerEngine.Application do
  @moduledoc false

  use Application

  alias Astarte.TriggerEngine.AMQPEventsConsumer

  def start(_type, _args) do
    children = [
      AMQPEventsConsumer
    ]

    opts = [strategy: :one_for_one, name: Astarte.TriggerEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
