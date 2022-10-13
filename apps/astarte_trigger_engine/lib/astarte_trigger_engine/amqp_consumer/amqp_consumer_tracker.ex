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

defmodule Astarte.TriggerEngine.AMQPConsumer.AMQPConsumerTracker do
  require Logger

  use GenServer
  alias Astarte.TriggerEngine.AMQPConsumer.Queries
  alias Astarte.TriggerEngine.AMQPConsumer.AMQPConsumerSupervisor
  alias Astarte.TriggerEngine.AMQPConsumer.AMQPMessageConsumer
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.Policy.KeywordError
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto

  # 30 seconds
  @update_timeout 30 * 1000

  # Client

  def start_link(default) when is_list(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  # Server callbacks

  @impl true
  def init(args \\ []) do
    schedule_update()
    {:ok, args}
  end

  @impl true
  def handle_info(:update_consumers, state) do
    registered_consumers =
      Registry.select(Registry.AMQPConsumerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    _ = Logger.debug("registered_consumers: #{inspect(registered_consumers)}")

    new_consumers =
      fetch_all_policies_with_realms_list()
      |> Enum.reject(fn {realm, {policy_name, _policy_data}} ->
        {realm, policy_name} in registered_consumers
      end)

    _ = Logger.debug("new_consumers: #{inspect(new_consumers)}")

    Enum.each(new_consumers, &start_new_consumer/1)

    schedule_update()

    {:noreply, state}
  end

  defp schedule_update() do
    Process.send_after(__MODULE__, :update_consumers, @update_timeout)
  end

  defp start_new_consumer({realm_name, {policy_name, policy_data}}) do
    _ =
      Logger.debug("Found new policy queue for #{realm_name}, #{policy_name}, starting consumer")

    policy =
      policy_data
      |> PolicyProto.decode()
      |> Policy.from_policy_proto!()

    child =
      {AMQPMessageConsumer,
       [
         realm_name: realm_name,
         policy: policy,
         pool_id: :events_consumer_pool
       ]}

    {:ok, _pid} = AMQPConsumerSupervisor.start_child(child)
  end

  defp fetch_all_policies_with_realms_list() do
    with {:ok, realm_names} <- Queries.list_realms() do
      Enum.reduce(realm_names, [], fn realm_name, acc ->
        fetch_realm_policies_list(realm_name) ++ acc
      end)
    end
  end

  defp fetch_realm_policies_list(realm_name) do
    policies = do_fetch_realm_policies_list(realm_name)
    real_policies = Enum.map(policies, fn x -> {realm_name, x} end)
    [{realm_name, default_policy()} | real_policies]
  end

  defp do_fetch_realm_policies_list(realm_name) do
    with {:ok, policies_list} <- Queries.list_policies(realm_name) do
      policies_list
    end
  end

  # we need this because the default policy cannot be installed
  defp default_policy() do
    name = "@default"

    policy = %Policy{
      name: name,
      maximum_capacity: 100,
      error_handlers: [
        %Handler{on: %KeywordError{keyword: "any_error"}, strategy: "discard"}
      ]
    }

    policy =
      policy
      |> Policy.to_policy_proto()
      |> PolicyProto.encode()

    {name, policy}
  end
end
