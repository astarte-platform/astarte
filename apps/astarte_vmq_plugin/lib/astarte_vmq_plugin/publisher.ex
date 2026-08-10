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

defmodule Astarte.VMQ.Plugin.Publisher do
  @moduledoc "GenServer wrapping VerneMQ's registered publish function to send messages over AMQP."
  use GenServer

  # API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def publish([token | _rest] = topic, payload, qos)
      when is_binary(token) and is_binary(payload) and is_integer(qos) do
    GenServer.call(__MODULE__, {:publish, topic, payload, qos})
  end

  # Callbacks

  def init([registry_mfa]) do
    {module, fun, args} = registry_mfa
    {register_fun, publish_fun, _sub_and_unsub_fun} = apply(module, fun, args)
    true = is_function(register_fun, 0)
    true = is_function(publish_fun, 3)
    :ok = register_fun.()
    {:ok, %{publish_fun: publish_fun}}
  end

  def handle_call({:publish, topic, payload, qos}, _from, %{publish_fun: publish_fun} = state) do
    reply = publish_fun.(topic, payload, %{qos: qos})
    {:reply, reply, state}
  end
end
