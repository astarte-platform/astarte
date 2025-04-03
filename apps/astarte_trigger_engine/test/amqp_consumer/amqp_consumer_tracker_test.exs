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

defmodule Astarte.TriggerEngine.AMQPConsumer.AMQPConsumerTrackerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.TriggerEngine.AMQPConsumer.AMQPConsumerTracker
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.TriggerEngine.DatabaseTestHelper

  @test_realm DatabaseTestHelper.test_realm()

  setup_all do
    astarte_instance_id = "test#{System.unique_integer([:positive])}"

    Astarte.DataAccess.Config
    |> stub(:astarte_instance_id, fn -> {:ok, astarte_instance_id} end)
    |> stub(:astarte_instance_id!, fn -> astarte_instance_id end)

    DatabaseTestHelper.create_test_env()

    on_exit(fn ->
      Astarte.DataAccess.Config
      |> stub(:astarte_instance_id, fn -> {:ok, astarte_instance_id} end)
      |> stub(:astarte_instance_id!, fn -> astarte_instance_id end)

      DatabaseTestHelper.drop_test_env()
    end)

    %{astarte_instance_id: astarte_instance_id}
  end

  setup %{astarte_instance_id: astarte_instance_id} do
    Astarte.DataAccess.Config
    |> stub(:astarte_instance_id, fn -> {:ok, astarte_instance_id} end)
    |> stub(:astarte_instance_id!, fn -> astarte_instance_id end)

    :ok
  end

  test "@default policy consumer is always there" do
    # make sure we update the consumer list without waiting for the update timeout
    AMQPConsumerTracker.update_consumers()

    assert Enum.member?(
             Registry.select(Registry.AMQPConsumerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}]),
             {@test_realm, "@default"}
           )
  end

  test "consumer for policy is created when a new policy is added" do
    policy_name = "policy_name"

    policy = %Policy{
      name: policy_name,
      retry_times: 1,
      maximum_capacity: 100,
      error_handlers: [
        %Handler{on: %ErrorKeyword{keyword: "any_error"}, strategy: "retry"}
      ]
    }

    DatabaseTestHelper.install_policy(policy)

    # make sure we update the consumer list without waiting for the update timeout
    AMQPConsumerTracker.update_consumers()

    assert Enum.member?(
             Registry.select(Registry.AMQPConsumerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}]),
             {@test_realm, policy_name}
           )
  end

  test "consumer for new policy is removed when a policy is removed" do
    policy_name = "another_policy_name"

    policy = %Policy{
      name: policy_name,
      retry_times: 1,
      maximum_capacity: 100,
      error_handlers: [
        %Handler{on: %ErrorKeyword{keyword: "any_error"}, strategy: "retry"}
      ]
    }

    DatabaseTestHelper.install_policy(policy)

    # make sure we update the consumer list without waiting for the update timeout
    AMQPConsumerTracker.update_consumers()

    assert Enum.member?(
             Registry.select(Registry.AMQPConsumerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}]),
             {@test_realm, policy_name}
           )

    trace_registry()
    DatabaseTestHelper.delete_policy(policy_name)

    # make sure we update the consumer list without waiting for the update timeout
    AMQPConsumerTracker.update_consumers()
    ensure_element_deleted()

    assert not Enum.member?(
             Registry.select(Registry.AMQPConsumerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}]),
             {@test_realm, policy_name}
           )
  end

  defp trace_registry(registry \\ Registry.AMQPConsumerRegistry) do
    # Elixir registries use partitions to monitor processes; we need to monitor those
    # instead of the registry process

    registry
    |> Supervisor.which_children()
    |> Enum.filter(fn {_id, _pid, type, modules} ->
      type == :worker && modules == [Registry.Partition]
    end)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.each(fn partition -> :erlang.trace(partition, true, [:receive]) end)
  end

  defp ensure_element_deleted do
    # The partition received the message for the dead process
    assert_receive {:trace, _, :receive, {:EXIT, _, :shutdown}}

    # magic sauce
    Process.sleep(1)
  end
end
