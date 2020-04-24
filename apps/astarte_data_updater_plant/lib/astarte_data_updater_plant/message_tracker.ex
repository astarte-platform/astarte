#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.MessageTracker do
  alias Astarte.DataUpdaterPlant.MessageTracker.Server

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(Server, args, name: name)
  end

  def track_delivery(message_tracker, message_id, delivery_tag) do
    GenServer.cast(message_tracker, {:track_delivery, message_id, delivery_tag})
  end

  def register_data_updater(message_tracker) do
    GenServer.call(message_tracker, :register_data_updater, :infinity)
  end

  def can_process_message(message_tracker, message_id) do
    GenServer.call(message_tracker, {:can_process_message, message_id}, :infinity)
  end

  def ack_delivery(message_tracker, message_id) do
    GenServer.call(message_tracker, {:ack_delivery, message_id})
  end

  def discard(message_tracker, message_id) do
    GenServer.call(message_tracker, {:discard, message_id})
  end

  def deactivate(message_tracker) do
    GenServer.call(message_tracker, :deactivate, :infinity)
  end
end
