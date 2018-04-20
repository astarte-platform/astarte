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

defmodule Astarte.DataUpdaterPlant.MessageTracker.Server do
  alias Astarte.DataUpdaterPlant.AMQPDataConsumer
  use GenServer

  def start(opts \\ []) do
    GenServer.start(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    new_state = :queue.new()
    {:ok, new_state}
  end

  def handle_call(:register_data_updater, {pid, _ref}, state) do
    Process.monitor(pid)
    {:reply, :ok, state}
  end

  def handle_call({:can_process_message, delivery_tag}, _from, state) do
    case :queue.peek(state) do
      {:value, ^delivery_tag} ->
        {:reply, true, state}

      {:value, {:duplicated_delivery, ^delivery_tag}} ->
        {:reply, false, state}
    end
  end

  def handle_call({:ack_delivery, delivery_tag}, _from, state) do
    {{:value, ^delivery_tag}, new_state} = :queue.out(state)

    unless match?({:injected_msg, _ref}, delivery_tag) do
      :ok = AMQPDataConsumer.ack(delivery_tag)
    end

    {:reply, :ok, new_state}
  end

  def handle_cast({:track_delivery, delivery_tag, redelivered}, state) do
    cond do
      not redelivered ->
        new_state = :queue.in(delivery_tag, state)
        {:noreply, new_state}

      :queue.member(delivery_tag, state) ->
        new_state = :queue.in({:duplicated_delivery, delivery_tag}, state)
        {:noreply, new_state}

      true ->
        new_state = :queue.in(delivery_tag, state)
        {:noreply, new_state}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    new_state = reject_all(state)
    {:noreply, new_state}
  end

  def reject_all(queue) do
    case :queue.out(queue) do
      {{:value, delivery_tag}, new_queue} ->
        unless match?({:injected_msg, _ref}, delivery_tag) do
          :ok = AMQPDataConsumer.requeue(delivery_tag)
        end

        reject_all(new_queue)

      {:empty, new_queue} ->
        new_queue
    end
  end
end
