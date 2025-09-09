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

defmodule Astarte.DataUpdaterPlant.AMQPEventsProducerTest do
  # Needs to be executed synchronously to avoid dirsrupting other tests
  use ExUnit.Case
  use Mimic

  alias AMQP.Channel
  alias Astarte.DataUpdaterPlant.AMQPEventsProducer

  @tag :regression
  test "events producer reconnects in case of error" do
    test_pid = self()
    pid = GenServer.whereis(AMQPEventsProducer)
    channel = :sys.get_state(pid)
    assert is_struct(channel, Channel)

    ExRabbitPool
    |> expect(:checkout_channel, fn _conn -> {:error, :disconnected} end)
    |> expect(:checkout_channel, fn _conn -> {:error, :out_of_channels} end)
    |> expect(:checkout_channel, fn conn ->
      res = Mimic.call_original(ExRabbitPool, :checkout_channel, [conn])
      send(test_pid, :reconnection_done)

      res
    end)
    |> allow(self(), pid)

    Channel.close(channel)

    # Wait for reconnection to happen
    assert_receive :reconnection_done

    new_status = :sys.get_state(pid)
    assert is_struct(new_status, Channel)
  end
end
