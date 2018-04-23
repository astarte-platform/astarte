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
  def register_data_updater(message_tracker) do
    GenServer.call(message_tracker, :register_data_updater)
    Process.monitor(message_tracker)
  end

  def track_delivery(message_tracker, delivery_tag, redelivered) do
    GenServer.cast(message_tracker, {:track_delivery, delivery_tag, redelivered})
  end

  def can_process_message(message_tracker, delivery_tag) do
    GenServer.call(message_tracker, {:can_process_message, delivery_tag})
  end

  def ack_delivery(message_tracker, delivery_tag) do
    GenServer.call(message_tracker, {:ack_delivery, delivery_tag})
  end

  def discard(message_tracker, delivery_tag) do
    GenServer.call(message_tracker, {:discard, delivery_tag})
  end
end
