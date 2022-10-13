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

defmodule Astarte.TriggerEngine.AMQPConsumer.AMQPMessageConsumerTest do
  use ExUnit.Case
  import Mox

  alias Astarte.TriggerEngine.Config
  alias Astarte.TriggerEngine.AMQPConsumer.AMQPMessageConsumer
  alias Astarte.TriggerEngine.AMQPConsumer.AMQPConsumerSupervisor
  alias Astarte.Core.Triggers.Policy

  test "new queue is correctly declared when spawning consumer" do
    policy_name = "whatever"
    realm_name = "autotest"

    queue_name = "#{policy_name}_#{realm_name}_queue"
    routing_key = "#{policy_name}_#{realm_name}"
    exchange_name = Config.events_exchange_name!()

    mock =
      MockAdapter
      |> expect(:qos, 1, fn _, _ -> :ok end)
      |> expect(:declare_exchange, 1, fn _, ^exchange_name, _ -> :ok end)
      |> expect(:declare_queue, 1, fn _, ^queue_name, _ -> {:ok, queue_name} end)
      |> expect(:queue_bind, 1, fn _, ^queue_name, ^exchange_name, routing_key: ^routing_key ->
        :ok
      end)
      |> expect(:consume, 1, fn _, ^queue_name, _, _ -> {:ok, "consumer_tag"} end)

    child =
      {AMQPMessageConsumer,
       [
         realm_name: realm_name,
         policy: %Policy{name: policy_name},
         pool_id: :events_consumer_pool
       ]}

    {:ok, pid} = AMQPConsumerSupervisor.start_child(child)

    Mox.allow(mock, self(), pid)
  end
end
