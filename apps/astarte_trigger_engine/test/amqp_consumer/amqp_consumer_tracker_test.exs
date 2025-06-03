#
# This file is part of Astarte.
#
# Copyright 2022 - 2025 SECO Mind Srl
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
  use Astarte.Cases.Database, async: true
  use Mimic

  alias Astarte.TriggerEngine.AMQPConsumer.AMQPConsumerTracker
  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator

  import Astarte.Helpers.Policy

  test "@default policy consumer is always there", %{realm_name: realm_name} do
    AMQPConsumerTracker.update_consumers()

    assert policy_consumer_available?(realm_name, "@default")
  end

  test "consumer for policy is created when a new policy is added", %{realm_name: realm_name} do
    policy = PolicyGenerator.policy() |> Enum.at(0)
    install_policy(realm_name, policy)

    assert policy_consumer_available?(realm_name, policy.name)
  end

  describe "consumer for a new policy is removed" do
    setup %{realm_name: realm_name} do
      policy = PolicyGenerator.policy() |> Enum.at(0)

      install_policy(realm_name, policy)
      %{policy: policy}
    end

    test "when a policy is removed", %{realm_name: realm_name, policy: policy} do
      delete_policy(realm_name, policy.name)

      refute policy_consumer_available?(realm_name, policy.name)
    end
  end
end
