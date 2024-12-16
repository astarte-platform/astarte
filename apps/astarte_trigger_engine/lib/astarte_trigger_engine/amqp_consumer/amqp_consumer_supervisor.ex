# Copyright 2017-2022 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.TriggerEngine.AMQPConsumer.AMQPConsumerSupervisor do
  require Logger
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    _ = Logger.info("Starting AMQP consumer supervisor", tag: "amqp_consumer_supervisor_start")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(child) do
    _ =
      Logger.info("Adding a new AMQP consumer",
        tag: "amqp_consumer_add"
      )

    DynamicSupervisor.start_child(__MODULE__, child)
  end

  def terminate_child(pid) do
    _ =
      Logger.info("Terminating an AMQP consumer",
        tag: "amqp_consumer_terminate"
      )

    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
