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

defmodule Astarte.Helpers.Policy do
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.TriggerEngine.AMQPConsumer.AMQPConsumerTracker

  import Ecto.Query

  @group "trigger_policy"

  def policy_consumer_available?(realm_name, policy_name) do
    # The registry is our source of truth
    Registry.AMQPConsumerRegistry
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.member?({realm_name, policy_name})
  end

  def install_policy(realm_name, policy) do
    policy_proto =
      policy
      |> Policy.to_policy_proto()
      |> PolicyProto.encode()

    keyspace_name = Realm.keyspace_name(realm_name)
    kv_store_map = %{group: @group, key: policy.name, value: policy_proto}

    :ok = KvStore.insert(kv_store_map, prefix: keyspace_name)
    AMQPConsumerTracker.update_consumers()
  end

  def delete_policy(realm_name, policy_name) do
    trace_registry()
    do_delete_policy(realm_name, policy_name)
    AMQPConsumerTracker.update_consumers()
    ensure_element_deleted(policy_name)
  end

  defp do_delete_policy(realm_name, policy_name) do
    keyspace_name = Realm.keyspace_name(realm_name)

    from(KvStore, where: [group: @group, key: ^policy_name])
    |> Repo.delete_all(prefix: keyspace_name)
  end

  defp trace_registry do
    Registry.AMQPConsumerRegistry
    |> Supervisor.which_children()
    |> Enum.filter(fn {_id, _pid, type, modules} ->
      type == :worker && modules == [Registry.Partition]
    end)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.each(fn partition -> :erlang.trace(partition, true, [:receive]) end)
  end

  defp ensure_element_deleted(policy_name) do
    # The partition received the message for the dead process
    receive do
      {:trace, _, :receive, {:EXIT, _, :shutdown}} -> :ok
    after
      1000 -> raise "policy not deleted: #{policy_name}"
    end

    # magic sauce
    Process.sleep(1)
  end
end
