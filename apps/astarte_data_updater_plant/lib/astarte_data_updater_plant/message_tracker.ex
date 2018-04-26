#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.MessageTracker do
  alias Astarte.DataUpdaterPlant.MessageTracker.Server

  def start(opts \\ []) do
    GenServer.start(Server, :ok, opts)
  end

  def track_delivery(message_tracker, message_id, delivery_tag, redelivered) do
    GenServer.cast(message_tracker, {:track_delivery, message_id, delivery_tag, redelivered})
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
end
