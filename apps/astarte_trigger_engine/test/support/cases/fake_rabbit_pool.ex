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

defmodule Astarte.Cases.FakeRabbitPool do
  use ExUnit.CaseTemplate
  use Mimic

  alias AMQP.Channel

  setup do
    connection = dummy_process()
    channel_process = dummy_process()

    channel = %Channel{conn: connection, pid: channel_process}

    ExRabbitPool
    |> stub(:get_connection_worker, fn :events_consumer_pool -> connection end)
    |> stub(:checkout_channel, fn ^connection -> {:ok, channel} end)

    ExRabbitPool.RabbitMQ
    |> stub_with(ExRabbitPool.FakeRabbitMQ)

    :ok
  end

  defp dummy_process do
    spawn(fn ->
      receive do
        :ok -> :ok
      end
    end)
  end
end
