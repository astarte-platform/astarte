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
  use ExUnit.Case

  alias Astarte.TriggerEngine.AMQPConsumer.AMQPConsumerTracker
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.TriggerEngine.DatabaseTestHelper

  @test_realm DatabaseTestHelper.test_realm()

  setup_all do
    DatabaseTestHelper.create_test_env()

    on_exit(&DatabaseTestHelper.drop_test_env/0)
    :ok
  end

  test "@default policy consumer is always there" do
    # make sure we update the consumer list without waiting for the update timeout
    AMQPConsumerTracker.handle_info(:update_consumers, [])

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
    AMQPConsumerTracker.handle_info(:update_consumers, [])

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
    AMQPConsumerTracker.handle_info(:update_consumers, [])
    Process.sleep(3000)

    assert Enum.member?(
             Registry.select(Registry.AMQPConsumerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}]),
             {@test_realm, policy_name}
           )

    DatabaseTestHelper.delete_policy(policy_name)

    # make sure we update the consumer list without waiting for the update timeout
    AMQPConsumerTracker.handle_info(:update_consumers, [])
    Process.sleep(3000)

    assert not Enum.member?(
             Registry.select(Registry.AMQPConsumerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}]),
             {@test_realm, policy_name}
           )
  end
end
