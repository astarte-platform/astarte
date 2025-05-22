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

defmodule Astarte.TriggerEngine.AMQPConsumer.AMQPMessageConsumer.Impl do
  alias AMQP.Channel
  alias AMQP.Basic
  alias Astarte.TriggerEngine.Config
  alias Astarte.Core.Triggers.Policy, as: PolicyStruct
  alias ExRabbitPool.Consumer

  require Logger

  @adapter Config.amqp_adapter!()

  @type delivery_params() :: %{
          realm_name: String.t(),
          policy: PolicyStruct.t(),
          channel: Channel.t(),
          payload: Basic.payload(),
          meta: Consumer.meta()
        }

  @doc """
    Gets a connection worker out of the connection pool, if there is one available
    takes a channel out of it channel pool, if there is one available
    subscribe itself as a consumer process.
  """
  @spec connect(String.t(), PolicyStruct.t()) ::
          {:ok, Channel.t(), reference()} | {:error, reason :: term()}
  def connect(realm_name, policy) do
    conn = ExRabbitPool.get_connection_worker(:events_consumer_pool)

    with {:ok, channel} <- ExRabbitPool.checkout_channel(conn) do
      try_to_connect(realm_name, policy, channel)
    end
  end

  defp try_to_connect(realm_name, policy, channel) do
    %{pid: channel_pid} = channel

    exchange_name = Config.events_exchange_name!()
    queue_name = generate_queue_name(realm_name, policy.name)
    routing_key = generate_routing_key(realm_name, policy.name)

    with :ok <- @adapter.qos(channel, prefetch_count: Config.amqp_consumer_prefetch_count!()),
         :ok <- @adapter.declare_exchange(channel, exchange_name, type: :direct, durable: true),
         {:ok, _queue} <- @adapter.declare_queue(channel, queue_name, durable: true),
         :ok <-
           @adapter.queue_bind(
             channel,
             queue_name,
             exchange_name,
             routing_key: routing_key,
             arguments: [{"x-queue-mode", :longstr, "lazy"} | generate_policy_x_args(policy)]
           ),
         {:ok, _consumer_tag} <- @adapter.consume(channel, queue_name, self(), []) do
      ref = Process.monitor(channel_pid)

      _ =
        Logger.debug(
          "Queue #{queue_name} on exchange #{exchange_name} declared, bound with routing key #{routing_key}",
          tag: "queue_bound"
        )

      {:ok, channel, ref}
    end
  end

  defp generate_policy_x_args(%PolicyStruct{
         maximum_capacity: max_capacity,
         event_ttl: event_ttl
       }) do
    []
    |> put_x_arg_if(max_capacity != nil, fn -> {"x-max-length", :signedint, max_capacity} end)
    # AMQP message TTLs are in milliseconds!
    |> put_x_arg_if(event_ttl != nil, fn -> {"x-message-ttl", :signedint, event_ttl * 1_000} end)
  end

  defp put_x_arg_if(list, true, x_arg_fun), do: [x_arg_fun.() | list]
  defp put_x_arg_if(list, false, _x_arg_fun), do: list

  defp generate_queue_name(realm, policy) do
    "#{realm}_#{policy}_queue"
  end

  defp generate_routing_key(realm, policy) do
    "#{realm}_#{policy}"
  end
end
