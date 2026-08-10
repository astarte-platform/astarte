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

defmodule Astarte.VMQ.Plugin.Test.Helpers.AMQP do
  @moduledoc "Test helpers for opening AMQP channels, consumers and device queues."
  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Queue
  alias Astarte.VMQ.Plugin.Config

  def setup_channel! do
    amqp_opts = Config.amqp_options()
    {:ok, conn} = Connection.open(amqp_opts)
    {:ok, chan} = Channel.open(conn)
    chan
  end

  def setup_consumer!(pid, channel, queue_name) do
    {:ok, consumer_tag} =
      Queue.subscribe(channel, queue_name, fn payload, meta ->
        send(pid, {:amqp_msg, payload, meta})
      end)

    consumer_tag
  end

  def setup_device_queue!(chan, realm, encoded_device_id) do
    sharding_key = {realm, encoded_device_id}
    queue_prefix = Config.data_queue_prefix()
    queue_index = :erlang.phash2(sharding_key, Config.data_queue_count())
    queue_name = "#{queue_prefix}#{queue_index}"
    Queue.declare(chan, queue_name)
    queue_name
  end
end
