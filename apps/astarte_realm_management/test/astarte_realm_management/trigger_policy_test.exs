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

defmodule Astarte.RealmManagement.TriggerPolicyTest do
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto
  alias Astarte.Core.Triggers.Policy
  alias Astarte.RealmManagement.Engine
  alias Astarte.RealmManagement.Queries

  use Astarte.RealmManagement.DataCase, async: true
  use ExUnitProperties

  describe "Test trigger policy" do
    @describetag :trigger_policy

    property "is installed correctly", %{realm: realm} do
      check all(policy <- Astarte.Core.Generators.Triggers.Policy.policy()) do
        policy_json = Jason.encode!(policy)
        :ok = Engine.install_trigger_policy(realm, policy_json)

        {:ok, fetched_policy} = Queries.fetch_trigger_policy(realm, policy.name)

        fetched_policy =
          fetched_policy
          |> PolicyProto.decode()
          |> Policy.from_policy_proto!()

        assert policy.event_ttl == fetched_policy.event_ttl
        assert policy.maximum_capacity == policy.maximum_capacity
        assert policy.name == fetched_policy.name
        assert (policy.prefetch_count || 0) == fetched_policy.prefetch_count
        assert (policy.retry_times || 0) == fetched_policy.retry_times

        assert Enum.sort(policy.error_handlers) == Enum.sort(fetched_policy.error_handlers)

        _ = Engine.delete_trigger_policy(realm, policy.name)
      end
    end

    property "is deleted correctly", %{realm: realm} do
      check all(policy <- Astarte.Core.Generators.Triggers.Policy.policy()) do
        policy_json = Jason.encode!(policy)
        _ = Engine.install_trigger_policy(realm, policy_json)

        :ok = Engine.delete_trigger_policy(realm, policy.name)

        {:error, :trigger_policy_not_found} = Engine.trigger_policy_source(realm, policy.name)
      end
    end
  end
end
